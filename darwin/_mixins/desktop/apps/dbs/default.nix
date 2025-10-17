{ pkgs, ... }:
{
  homebrew = {

    brews = [
      "cmake" # Required for timescaledb
      "libpq"
      "postgresql@14"
      "postgresql@16"
      "postgresql@17"
    ];

    casks = [
      "pgadmin4"
      "clickhouse"
    ];

  };

  environment.systemPackages = with pkgs; [
    influxdb2
    influxdb2-cli
    influxdb3
  ];
}
