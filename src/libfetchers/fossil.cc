#include "config.hh"
#include "fetchers.hh"
#include "cache.hh"
#include "globals.hh"
#include "store-api.hh"
#include "url-parts.hh"
#include "fetch-settings.hh"
#include <sys/time.h>
#include <nlohmann/json.hpp>
#include <iostream>

using namespace std::string_literals;

namespace nix::fetchers {

bool isCacheFileWithinTtl(time_t now, const struct stat & st)
{
    return st.st_mtime + settings.tarballTtl > now;
}

bool touchCacheFile(const Path & path, time_t touch_time)
{
    struct timeval times[2];
    times[0].tv_sec = touch_time;
    times[0].tv_usec = 0;
    times[1].tv_sec = touch_time;
    times[1].tv_usec = 0;

    return lutimes(path.c_str(), times) == 0;
}
  
static RunOptions fossilOptions(const Strings & args)
{
    auto env = getEnv();

    return {
        .program = "fossil",
        .searchPath = true,
        .args = args,
        .environment = env
    };
}

static std::string runFossil(const Strings & args, const std::optional<std::string> & input = {})
{
    RunOptions opts = fossilOptions(args);
    opts.input = input;

    auto res = runProgram(std::move(opts));

    if (!statusOk(res.first))
        throw ExecError(res.first, fmt("fossil %1%", statusToString(res.first)));

    return res.second;
}

struct FossilInputScheme : InputScheme
{
    std::optional<Input> inputFromURL(const ParsedURL & url, bool requireTree) const override
    {
        if (url.scheme != "fossil+http" &&
            url.scheme != "fossil+https" &&
            url.scheme != "fossil+ssh" &&
            url.scheme != "fossil+file") {
          return {};
        }

        auto url2(url);
        url2.scheme = std::string(url2.scheme, 7);
        url2.query.clear();

        Attrs attrs;
        attrs.emplace("type", "fossil");

        for (auto &[name, value] : url.query) {
            if (name == "rev" || name == "ref")
                attrs.emplace(name, value);
            else
                url2.query.emplace(name, value);
        }

        attrs.emplace("url", url2.to_string());

        return inputFromAttrs(attrs);
    }

    std::optional<Input> inputFromAttrs(const Attrs & attrs) const override
    {
        if (maybeGetStrAttr(attrs, "type") != "fossil") return {};

        for (auto & [name, value] : attrs)
            if (name != "type" && name != "url" && name != "ref" && name != "rev"  && name != "narHash" && name != "name")
                throw Error("unsupported Fossil input attribute '%s'", name);

        parseURL(getStrAttr(attrs, "url"));

        Input input;
        input.attrs = attrs;
        return input;
    }

    ParsedURL toURL(const Input & input) const override
    {
        auto url = parseURL(getStrAttr(input.attrs, "url"));
        url.scheme = "fossil+" + url.scheme;
        if (auto rev = input.getRev()) url.query.insert_or_assign("rev", rev->to_string(Base16, true));
        if (auto ref = input.getRef()) url.query.insert_or_assign("ref", *ref);
        return url;
    }

    bool hasAllInfo(const Input & input) const override
    {
      // bool maybeDirty = !input.getRef();
      // return maybeGetIntAttr(input.attrs, "lastModified") && maybeDirty;
      return true;
    }

    Input applyOverrides(
        const Input & input,
        std::optional<std::string> ref,
        std::optional<Hash> rev) const override
    {
        auto res(input);
        if (rev) res.attrs.insert_or_assign("rev", rev->to_string(Base16, true));
        if (ref) res.attrs.insert_or_assign("ref", *ref);
        if (!res.getRef() && res.getRev())
            throw Error("Fossil input '%s' has a commit hash but no branch/tag name", res.to_string());
        return res;
    }

    void clone(const Input & input, const Path & destDir) const override
    {
        auto [isLocal, actualUrl] = getActualUrl(input);

        runFossil({ "clone", "--no-open", actualUrl, destDir });
    }

    std::optional<Path> getSourcePath(const Input & input) override
    {
        auto url = parseURL(getStrAttr(input.attrs, "url"));
        if (url.scheme == "file" && !input.getRef() && !input.getRev())
            return url.path;
        return {};
    }

    void markChangedFile(const Input & input, std::string_view file, std::optional<std::string> commitMsg) override
    {
        auto sourcePath = getSourcePath(input);
        assert(sourcePath);

        std::cout << "BOOM2: " << *sourcePath << std::endl;
        runFossil(
            { "--chdir", *sourcePath, "add", std::string(file) });

        if (commitMsg)
            runFossil(
                { "--chdir", *sourcePath, "commit", std::string(file), "-m", *commitMsg });
    }

    std::pair<bool, std::string> getActualUrl(const Input & input) const
    {
        auto url = parseURL(getStrAttr(input.attrs, "url"));
        bool isLocal = url.scheme == "file";
        std::cout << "BOOM11: " << isLocal << "; " << url.scheme << std::endl;
        return {isLocal, isLocal ? url.path : url.base};
    }

    std::pair<StorePath, Input> fetch(ref<Store> store, const Input & _input) override
    {
        Input input(_input);

        std::string name = input.getName();

        auto cacheType = "fossil";

        auto checkHashType = [&](const std::optional<Hash> & hash)
        {
            if (hash.has_value() && !(hash->type == htSHA1 || hash->type == htSHA256))
                throw Error("Hash '%s' is not supported by Fossil. Supported types are sha1 and sha256.", hash->to_string(Base16, true));
        };

        auto getLockedAttrs = [&]()
        {
           checkHashType(input.getRev());

            return Attrs({
                {"type", cacheType},
                {"name", name},
                // NOTE: not sure if should include the hash type prefix or not
                {"rev", input.getRev()->to_string(Base16, false)},
            });
        };

        auto makeResult = [&](const Attrs & infoAttrs, StorePath && storePath)
            -> std::pair<StorePath, Input>
        {
            assert(input.getRev());
            assert(!_input.getRev() || _input.getRev() == input.getRev());
            // input.attrs.insert_or_assign("revCount", getIntAttr(infoAttrs, "revCount"));
            input.attrs.insert_or_assign("lastModified", getIntAttr(infoAttrs, "lastModified"));
            return {std::move(storePath), input};
        };

        if (input.getRev()) {
            if (auto res = getCache()->lookup(store, getLockedAttrs()))
                return makeResult(res->first, std::move(res->second));
        }

        auto [isLocal, actualUrl_] = getActualUrl(input);
        auto actualUrl = actualUrl_; // work around clang bug

        if (!input.getRef() && !input.getRev() && isLocal) {

            /* NOTE: Not in git fetcher anymore, let's try leaving this out
            bool clean = false;

            auto changes = runFossil({ "--chdir", actualUrl, "changes", "--extra", "--merge", "--dotfiles" });

            if (changes.length() == 0) clean = true;

            if (!clean) {
            */
                if (!fetchSettings.allowDirty)
                    throw Error("Fossil tree '%s' is dirty", actualUrl);

                if (fetchSettings.warnDirty)
                    warn("Fossil tree '%s' is dirty", actualUrl);
            /*
            }
            */

                std::cout << "BOOM1: " << actualUrl << std::endl;

            auto files = tokenizeString<std::set<std::string>>(runFossil({ "--chdir", actualUrl, "ls" }), "\n"s);

            Path actualPath(absPath(actualUrl));
            
            PathFilter filter = [&](const Path & p) -> bool {
                assert(hasPrefix(p, actualPath));
                std::string file(p, actualPath.size() + 1);

                auto st = lstat(p);

                if (S_ISDIR(st.st_mode)) {
                    auto prefix = file + "/";
                    auto i = files.lower_bound(prefix);
                    return i != files.end() && hasPrefix(*i, prefix);
                }

                return files.count(file);
            };

            auto storePath = store->addToStore(input.getName(), actualPath, FileIngestionMethod::Recursive, htSHA256, filter);
            std::cout << "BOOM3: " << actualPath << std::endl;
            auto json = nlohmann::json::parse(runFossil({ "--chdir", actualPath, "json", "status" }));
            std::uint64_t timestamp = json["payload"]["checkout"]["timestamp"];
            input.attrs.insert_or_assign("lastModified", timestamp);

            return {std::move(storePath), input};
        }

        // NOTE: not in git fetcher
        // if (!input.getRef()) input.attrs.insert_or_assign("ref", "trunk");

        // NOTE: not in git fetcher
        // auto revOrRef = input.getRev() ? input.getRev()->to_string(Base16, false) : *input.getRef();

        Attrs unlockedAttrs({
            {"type", cacheType},
            {"name", name},
            {"url", actualUrl},
            // NOTE: not in git fetcher
            // {"ref", *input.getRef()},
        });

        if (isLocal) {
          if (!input.getRef()) {
            std::cout << "BOOM4: " << actualUrl << std::endl;
            auto json = nlohmann::json::parse(runFossil({ "--chdir", actualUrl, "json", "branch", "list" }));
            std::string branch = json["payload"]["current"];
            input.attrs.insert_or_assign("ref", branch);
            unlockedAttrs.insert_or_assign("ref", branch);
          }

          if (!input.getRev()) {
            std::cout << "BOOM5: " << actualUrl << std::endl;
            auto json = nlohmann::json::parse(runFossil({ "--chdir", actualUrl, "json", "status" }));
            std::string uuid = json["payload"]["checkout"]["uuid"];
            input.attrs.insert_or_assign("rev", uuid);
          }
        } else if (!input.getRef()) {
          input.attrs.insert_or_assign("ref", "trunk");
          unlockedAttrs.insert_or_assign("ref", "trunk");
        } else if (!input.getRev()) {
          unlockedAttrs.insert_or_assign("ref", input.getRef().value());
        }

        if (auto res = getCache()->lookup(store, unlockedAttrs)) {
            Hash hash = Hash::parseAny("", htSHA1);
            try {
              hash = Hash::parseAny(getStrAttr(res->first, "rev"), htSHA256);
            } catch (BadHash & e) {
              try {
                hash = Hash::parseAny(getStrAttr(res->first, "rev"), htSHA1);
              } catch (BadHash & e) {
                throw Error("Hash '%s' is neither sha256 nor sha1");
              }
            }

            auto rev2 = hash;
            if (!input.getRev() || input.getRev() == rev2) {
                input.attrs.insert_or_assign("rev", rev2.to_string(Base16, true));
                return makeResult(res->first, std::move(res->second));
            }
        }

        Path repoFile = fmt("%s/nix/fossilv1/repos/%s", getCacheDir(), hashString(htSHA256, actualUrl).to_string(Base32, false));
        Path checkoutDir = fmt("%s/nix/fossilv1/checkouts/%s", getCacheDir(), hashString(htSHA256, actualUrl).to_string(Base32, false));

        Activity act(*logger, lvlTalkative, actUnknown, fmt("fetching Fossil repository '%s'", actualUrl));

        if (!pathExists(repoFile)) {
          createDirs(dirOf(repoFile));
          runFossil({ "clone", actualUrl, repoFile });
        }
        if (!pathExists(checkoutDir)) {
            createDirs(dirOf(checkoutDir));
            runFossil({ "open", repoFile, "--workdir", checkoutDir });
        }

        bool doUpdate = false;
        time_t now = time(0);

        if (input.getRev()) {
          try {
            std::cout << "BOOM7: " << checkoutDir << std::endl;
            runFossil({ "--chdir", checkoutDir, "info", input.getRev()->to_string(Base16, false) });
          } catch (ExecError &e) {
            if (WIFEXITED(e.status)) {
              doUpdate = true;
            } else {
              throw;
            }
          }
        } else {
          struct stat st;
          doUpdate = stat(repoFile.c_str(), &st) != 0 || !isCacheFileWithinTtl(now, st);
        }

        if (doUpdate) {
            Activity act(*logger, lvlTalkative, actUnknown, fmt("fetching Fossil repository '%s'", actualUrl));
            try {
              auto ref = input.getRef();
              std::cout << "BOOM8: " << checkoutDir << std::endl;
              runFossil({ "--chdir", checkoutDir, "up", *ref });
            } catch (Error & e) {
              if (!pathExists(repoFile)) throw;
              warn("could not update local clone of Fossil repository '%s'; continuing with the most recent version", actualUrl);
            }

            if (!touchCacheFile(repoFile, now))
                warn("could not update mtime for file '%s': %s", repoFile, strerror(errno));
        }

        if (!input.getRev()) {
          std::cout << "BOOM9: " << checkoutDir << std::endl;
          auto json = nlohmann::json::parse(runFossil({ "--chdir", checkoutDir, "json", "status"}));
          std::string uuid = json["payload"]["checkout"]["uuid"];
          std::string hash;
          try {
            hash = Hash::parseAny(uuid, htSHA256).to_string(Base16, true);
          } catch (BadHash & e) {
            try {
              hash = Hash::parseAny(uuid, htSHA1).to_string(Base16, true);
            } catch (BadHash & e) {
              throw Error("Hash '%s' is neither sha256 nor sha1", uuid);
            }
          }
          input.attrs.insert_or_assign("rev",hash);
        }

        printTalkative("using revision %s of repo '%s'", input.getRev()->to_string(Base16,true), actualUrl);

        // auto json2 = nlohmann::json::parse(runFossil({ "--chdir", ckout, "json", "branch", "list"}));
        // input.attrs.insert_or_assign("ref", std::string { json2["payload"]["current"] });

        auto cache = getCache();

        auto theattrs = getLockedAttrs();

        auto res = cache->lookup(store, theattrs);

        if (res) {
            return makeResult(res->first, std::move(res->second));
        }

        auto storePath = store->addToStore(name, checkoutDir, FileIngestionMethod::Recursive, htSHA256, defaultPathFilter);

        std::cout << "BOOM10: " << actualUrl << std::endl;
        auto json = nlohmann::json::parse(runFossil({ "--chdir", checkoutDir, "json", "status" }));
        std::uint64_t lastModified = json["payload"]["checkout"]["timestamp"];

        Attrs infoAttrs({
            {"rev", input.getRev()->to_string(Base16, true)},
            {"lastModified", lastModified},
        });

        if (!_input.getRev())
            getCache()->add(
                store,
                unlockedAttrs,
                infoAttrs,
                storePath,
                false);

        getCache()->add(
            store,
            getLockedAttrs(),
            infoAttrs,
            storePath,
            true);

        return makeResult(infoAttrs, std::move(storePath));
    }
};

static auto rFossilInputScheme = OnStartup([] { registerInputScheme(std::make_unique<FossilInputScheme>()); });

}
