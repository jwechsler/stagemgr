# Build Hints

## MySQL2 Gem Installation

When installing the `mysql2` gem on macOS with MySQL 8+ and zstd dependencies, you need to set specific environment variables:

```bash
export LDFLAGS="-L/opt/homebrew/opt/zstd/lib -lzstd"
export LIBRARY_PATH="/opt/homebrew/opt/zstd/lib:$LIBRARY_PATH"
```

Then install the gem with:

```bash
gem install mysql2 -- --with-mysql-config=/opt/homebrew/opt/mysql-client/bin/mysql_config --verbose
```

### Common Issues

1. **Missing zstd Library**: If you encounter `ld: library 'zstd' not found`, make sure to:
   - Install zstd: `brew install zstd`
   - Set both `LDFLAGS` and `LIBRARY_PATH` as shown above

2. **MySQL Client**: Ensure MySQL client is installed:
   - Install: `brew install mysql-client`
   - Check installation: `ls /opt/homebrew/opt/mysql-client/lib`

3. **Version Compatibility**: 
   - MySQL Server: 8.x
   - MySQL Client: 8.x
   - Avoid mixing major versions of MySQL server and client
