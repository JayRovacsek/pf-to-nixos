{ self, ... }:
let

  inherit (self.inputs.nixpkgs) lib;

  inherit (lib) foldlAttrs mapAttrs mapAttrsToList recursiveUpdate toInt;

  second = 1;
  minute = 60 * second;
  hour = 60 * minute;

  parse-lease-time = s:
    let n = (toInt s);
    in if n < 0 then
      builtins.throw "NOPE"
    else if n < minute then
      "${s}s"
    else if n < hour then
      "${builtins.toString (seconds-to-minutes n)}m"
    else
      "${builtins.toString (seconds-to-hours n)}h";

  seconds-to-minutes = seconds: builtins.floor (seconds / minute);
  seconds-to-hours = seconds: builtins.floor (seconds / hour);

  merge = a: builtins.foldl' (a: v: recursiveUpdate a v) { } a;
  merge-values = s: foldlAttrs (a: n: v: recursiveUpdate a v) { } s;

  is-wan = interface: builtins.hasAttr "blockbogons" interface;

  is-vlan = interface:
    [ ] == (builtins.match "[[:alnum:]]+[\\.]{1}[[:digit:]]+" interface."if");

  is-vpn = interface: !(builtins.hasAttr "ipaddr" interface);

  is-network = interface:
    !(is-wan interface) && !(is-vlan interface) && !(is-vpn interface);

  interface-uses-dhcp = interface: interface.ipaddr == "dhcp";

  match-interface = interface: if is-vlan interface then "vlan" else "network";

  parse-vlan = name: interface: _: {
    # TODO: correct this to create network, netdev and bindings between
    systemd.network.networks.${name} = {

      matchConfig.Name = interface."if";
      networkConfig = {
        Address = interface.ipaddr;
        Description = interface.descr;
      };
    };
  };

  parse-network = name: interface: _: {
    systemd.network.networks.${name} = {

      matchConfig.Name = interface."if";
      networkConfig = {
        Address = interface.ipaddr;
        Description = interface.descr;
        IPForward = "yes";
      };

    };
  };

  parse-vpn = name: interface: _:
    {
      # TODO: Implement
    };

  parse-wan = name: interface: cfg: {
    # TODO: 
    # Validate DNS approach, it seems wrong
    # Configure some basic other options like pppoe
    # or static addresses
    systemd.network.networks.${name} = {

      matchConfig.Name = interface."if";

      dns = cfg.pfsense.system.dnsserver;

      networkConfig = let
        ip-configuration = if interface-uses-dhcp interface then {
          DHCP = "yes";
        } else {
          Address = interface.ipaddr;
        };
      in ip-configuration // {
        Description = interface.descr;
        IPForward = "yes";
      };

    };
  };

  parse-map = {
    network = parse-network;
    vlan = parse-vlan;
    vpn = parse-vpn;
    wan = parse-wan;
  };

  parse-dhcp = cfg:
    let
      per-interface-settings = mapAttrsToList (name: interface: {
        dhcp-range = if name != "dhcpddata" then
          let
            lease-time = if interface.defaultleasetime == null then
              "2h"
            else
              parse-lease-time interface.defaultleasetime;
          in [
            "interface:${name},${interface.range.from},${interface.range.to},${lease-time}"
          ]
        else
          [ ];
      }) cfg.pfsense.dhcpd;
    in builtins.foldl'
    (acc: v: { dhcp-range = acc.dhcp-range ++ v.dhcp-range; }) {
      dhcp-range = [ ];
    } per-interface-settings;

  parse-interfaces = cfg:
    merge-values (mapAttrs (name: interface:
      let
        wan = is-wan interface;
        vlan = is-vlan interface;
        vpn = is-vpn interface;
        network = is-network interface;

        parser = if wan then
          "wan"
        else if vlan then
          "vlan"
        else if network then
          "network"
        else if vpn then
          "vpn"
        else
          builtins.throw "UNMATCHED INTERFACE TYPE";

      in parse-map.${parser} name interface cfg) cfg.pfsense.interfaces);

  load-config = file: builtins.fromJSON (builtins.readFile file);
  parse-config = file:
    let
      cfg = load-config file;
      interfaces = parse-interfaces cfg;
      dhcpd = parse-dhcp cfg;
    in merge [ dhcpd interfaces ];

in { inherit load-config parse-interfaces parse-config; }
