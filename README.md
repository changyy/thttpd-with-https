# thttpd-with-https

A lightweight HTTPS server solution combining thttpd 2.29 and stunnel, designed for easy deployment and cross-compilation.

## Features

- Lightweight HTTP server (thttpd 2.29)
- HTTPS support via stunnel
- Easy configuration and deployment
- Cross-compilation support
- Automatic certificate generation
- Convenient management scripts

## Prerequisites

- CMake 3.10 or higher
- C compiler (gcc/clang)
- OpenSSL development package
- Make or Ninja build system

### macOS (via Homebrew)
```bash
brew install cmake openssl@3
```

### Linux (Debian/Ubuntu)
```bash
sudo apt install cmake build-essential libssl-dev
```

## Quick Start

```bash
# Clone the repository
git clone https://github.com/changyy/thttpd-with-https.git
cd thttpd-with-https

# Build
mkdir build && cd build
cmake -DTHTTPD_PORT=8080 -DSTUNNEL_PORT=8443 ..
make collect

# Run
cd bin
./generate-cert.sh
./start-servers.sh

# Test
curl http://127.0.0.1:8080
curl -k https://127.0.0.1:8443

# Stop
./stop-servers.sh
```

## Build Options

- `THTTPD_PORT`: Set HTTP port (default: 8080)
- `STUNNEL_PORT`: Set HTTPS port (default: 8443)
- `ENABLE_SSL`: Enable HTTPS support (default: ON)
- `ENABLE_DEBUG`: Enable debug build (default: OFF)
- `ENABLE_TESTS`: Enable testing (default: OFF)

Example with custom ports:
```bash
cmake -DTHTTPD_PORT=8888 -DSTUNNEL_PORT=8443 ..
```

## Directory Structure

```
build/
  bin/                    # All executables and scripts
    thttpd               # HTTP server executable
    stunnel              # HTTPS proxy executable
    thttpd.conf          # HTTP server configuration
    stunnel.conf         # HTTPS proxy configuration
    generate-cert.sh     # SSL certificate generation script
    start-servers.sh     # Server startup script
    stop-servers.sh      # Server shutdown script
```

## Configuration Files

### thttpd.conf
```
port=8080               # HTTP port
dir=/tmp               # Web root directory
user=nobody            # Run as user
host=127.0.0.1         # Listen on localhost
```

### stunnel.conf
```
[https]
accept = 8443          # HTTPS port
connect = 127.0.0.1:8080  # Forward to HTTP port
cert = /tmp/certs/certificate.pem
key = /tmp/certs/private.key
```

## Cross Compilation

For cross-compilation, specify the toolchain file:

```bash
cmake -DCMAKE_TOOLCHAIN_FILE=<path-to-toolchain-file> ..
```

## Security Notes

- Default configuration uses self-signed certificates
- Certificates are stored in `/tmp/certs/`
- For production use:
  - Replace self-signed certificates with proper ones
  - Modify the web root directory from `/tmp`
  - Configure appropriate user permissions

## Tested Platforms

- macOS M2 (Apple Silicon)
- Linux x86_64 (planned)
- Linux ARM64 (planned)

## Contributing

Contributions are welcome! Please feel free to submit pull requests.

## Known Issues

- Self-signed certificates will generate browser warnings
- Some configurations are hardcoded to `/tmp` directory

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Third-party Licenses

This project includes:
- thttpd (version 2.29) - BSD-like License
- stunnel (version 5.73) - GPL v2 or later

Please see the [LICENSE](LICENSE) file for complete third-party license information.

Note: While the integration code and build system are MIT licensed, the included third-party components retain their original licenses. Users must comply with all applicable license terms.

## Credits

- [thttpd](http://www.acme.com/software/thttpd/): Original HTTP server
- [stunnel](https://www.stunnel.org/): SSL/TLS wrapper
