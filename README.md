# EBRAINS Services Toolbox for MATLAB

[![Version Number](https://img.shields.io/github/v/release/ehennestad/EBRAINS-MATLAB?label=version)](https://github.com/ehennestad/EBRAINS-MATLAB/releases/latest)
[![View {{cookiecutter.toolbox_name}} on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)]({{cookiecutter.fex_url}})
[![MATLAB Tests](.github/badges/tests.svg)](https://github.com/ehennestad/EBRAINS-MATLAB/actions/workflows/test-code.yml)
[![codecov](https://codecov.io/gh/ehennestad/EBRAINS-MATLAB/graph/badge.svg?token=H8GE1A76YI)](https://codecov.io/gh/ehennestad/EBRAINS-MATLAB)
[![MATLAB Code Issues](.github/badges/code_issues.svg)](https://github.com/ehennestad/EBRAINS-MATLAB/security/code-scanning)
[![Run Codespell](https://github.com/ehennestad/EBRAINS-MATLAB/actions/workflows/run-codespell.yml/badge.svg)](https://github.com/ehennestad/EBRAINS-MATLAB/actions/workflows/run-codespell.yml)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://gitHub.com/ehennestad/EBRAINS-MATLAB/graphs/commit-activity)


Lightweight MATLAB helpers and API clients to work with EBRAINS services (authentication, Data Proxy buckets, and KG metadata).

## Features
- Authenticate to EBRAINS using **device flow** or **client credentials flow**
- List bucket objects and compute bucket sizes (Data Proxy)
- Download Knowledge Graph (KG) metadata
- Interact with the Collaboratory API

## Requirements
- MATLAB (R2021a or newer recommended)
- EBRAINS account and internet access

## Installation
Clone the repo and add `src/` to your MATLAB path:

```matlab
addpath(genpath(fullfile(pwd, 'src')))
savepath  % optional
```

## Quick start

### 1) Authenticate
```matlab
ebrains.authenticate()
```
This will open a browser window that redirects to EBRAINS login page.
> [!TIP]
>  You can also provide a token via the environment variable `EBRAINS_TOKEN`.

### 2) Work with Data Proxy buckets
List objects and compute total size:
```matlab
objs = ebrains.bucket.listBucketObjects("my-bucket", 'Verbose', true);
bytes = ebrains.bucket.getBucketSize("my-bucket");
fprintf('Objects: %d, Size: %.2f GB\n', numel(objs), double(bytes)/1e9);
```

### 3) Download KG metadata
```matlab
[instance, collection] = ebrains.kg.downloadMetadata("kg:YOUR_IDENTIFIER", ...
	struct('NumLinksToResolve', 1, 'Verbose', true));
```

## See Also
### [openMINDS KG Sync](https://github.com/ehennestad/openminds-kg-sync)
A MATLAB toolbox that builds upon the EBRAINS MATLAB KG API to provide high-level functions for synchronizing [openMINDS](https://openminds.docs.om-i.org/en/latest/) metadata to and from the [EBRAINS Knowledge Graph](https://docs.kg.ebrains.eu). It offers convenient methods like `kglist`, `kgpull`, and `kgsave` for working with [openMINDS metadata types](https://github.com/openMetadataInitiative/openMINDS_MATLAB), handling serialization and deserialization of instances. If you need to work with structured neuroscience metadata using the openMINDS standard, this toolbox provides a streamlined interface on top of the lower-level `ebrains.kg.api.InstanceClient` functionality.

## Contributing
- Open an issue to discuss ideas/bugs.
- Fork, create a feature branch, add tests where practical, and open a PR.
