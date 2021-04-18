# This module defines a small NixOS installation CD.  It does not
# contain any graphical stuff.

{ ... }:

{
  imports =
    [ ./installation-cd-base.nix
    ];

  isoImage.edition = "minimal";

  fonts.fontconfig.enable = false;

  # Include the closure of a full system for offline installation.
  isoImage.storeContents =
    [ (import <nixpkgs/nixos> { configuration = /etc/nixos/configuration.nix; }).system ];
}
