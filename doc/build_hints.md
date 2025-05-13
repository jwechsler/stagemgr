# Build Hints

## Local Development Setup

Before running bundle install locally on macOS, source the environment setup script that is in site/bin:

```bash
source ~/dev/site/bin/setup_local_env.sh
bundle install
```

## MySQL2 and SQLite3 Gem Installation

When installing the `mysql2` and `sqlite3` gems on macOS, we use environment variables to configure the build process. The setup_local_env.sh script contains:

```bash
# Set up zstd dependencies
export LDFLAGS="-L/opt/homebrew/opt/zstd/lib -lzstd $LDFLAGS"
export LIBRARY_PATH="/opt/homebrew/opt/zstd/lib:$LIBRARY_PATH"

# SQLite3 build configuration
export BUNDLE_BUILD__SQLITE3="--with-sqlite3-include=/opt/homebrew/opt/sqlite/include --with-sqlite3-lib=/opt/homebrew/opt/sqlite/lib"

# MySQL2 build configuration
export BUNDLE_BUILD__MYSQL2="--with-mysql-config=/opt/homebrew/opt/mysql-client/bin/mysql_config"
```

For Docker environments, these are set in the Dockerfile:
```dockerfile
ENV BUNDLE_BUILD__SQLITE3="--with-sqlite3-include=/usr/include --with-sqlite3-lib=/usr/lib"
ENV BUNDLE_BUILD__MYSQL2="--with-mysql-config=/usr/bin/mysql_config"
```

### Prerequisites

Make sure you have the following installed:

- Homebrew
- MySQL Client: `brew install mysql-client`
- SQLite: `brew install sqlite3`
- zstd: `brew install zstd`

### Version Requirements

For optimal compatibility:
   - MySQL Server: 8.x
   - MySQL Client: 8.x
   - Avoid mixing major versions of MySQL server and client
