{ pkgs, ... }:
{
  homebrew = {
    taps = [
      "supabase/tap"
    ];

    brews = [
      "cmake" # Required for timescaledb
      "libpq" # 
      "postgresql@14" # Needed for psql cli
      "postgresql@17" # psql-17
      "sqlite3"
      "supabase"
    ];

    casks = [
      "dropbox"
      "pgadmin4"
    ];

  };

  environment.systemPackages = with pkgs; [
    influxdb2
    influxdb2-cli
    influxdb3
  ];
}
