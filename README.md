> **Check out our main project at [safing/portmaster](https://github.com/safing/portmaster)**

# mmdb-converter

This repository contains a simple CSV to mmdb converter.
It contains a simple HTTP server (written in Go) and a converter script (written in Perl).

## Input Format

The `convert.pl` script requires a CSV input file (without a header line) in the following
format:

```csv
ip-range,ASN,Country,ISP-Name
```

for example,
```csv
185.199.108.0/23,3659,US,Github
```

## Quick Start

The easiest way to use the mmdb-converter is to use docker, just build the container and run it:

```bash
# Clone the repository
git clone https://github.com/safing/mmdb-converter

# Enter the repository
cd mmdb-converter

# Build the docker container
docker build -t mmdb-converter .
```

Once the container is built (this may take a while), run it using:

```bash
docker run --rm -p 8080:8080 mmdb-converter
```

Finally, post a CSV file to the correct endpoint to get it converted to MMDB:

**For IPv4**:

```bash
curl -X POST --data '@csvfile' -H'Content-Type: text/csv' http://localhost:8080/convert/v4 -o mydb.mmdb
```

**For IPv6**:

```bash
curl -X POST --data '@csvfile' -H'Content-Type: text/csv' http://localhost:8080/convert/v6 -o mydb.mmdb
```

## Using `convert.pl` directly

To directly use convert.pl make sure to have `perl5` installed. Then, install
all dependencies fom [cpanfile](./cpanfile). Use whatever CPAN manager you're used
to. For example, with cpanm and carton:

```bash
# Execute from within the repository folder
sudo cpanm carton
carton install
```

The `convert.plg` script requires 3 arguments, an input CSV file, the filename for the MMDB file the
the expected IP version (`4` or `6`).

For example:

```bash
# -I is required if installed via carton.
perl -I ./local/lib/perl5/ ./convert.pl ./input.csv ./output.mmdb 6
```

# License

This repository is licensed under a BSD 3-Clause "New" or "Revised" License. See [LICENSE](./LICENSE) for more information.
