{ pkgs, ... }:
{
  homebrew = {

    brews = [
      "cmake" # Required for timescaledb
      #  "timescaledb"
      "libpq"
      "postgresql@16"
      "postgresql@17"
    ];

    casks = [
      "pgadmin4"
      "clickhouse"
    ];

    #taps = [
    #"timescale/tap"
    #];
  };

  environment.systemPackages = with pkgs; [
    influxdb2
    influxdb2-cli
    influxdb3
  ];
}
