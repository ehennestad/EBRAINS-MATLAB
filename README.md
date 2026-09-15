# EBRAINS Services Toolbox for MATLAB

[![Version Number](https://img.shields.io/github/v/release/ehennestad/EBRAINS-MATLAB?label=version)](https://github.com/ehennestad/EBRAINS-MATLAB/releases/latest)
[![View EBRAINS Services Toolbox on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://se.mathworks.com/matlabcentral/fileexchange/182284-ebrains-services-toolbox)
[![MATLAB Tests](.github/badges/tests.svg)](https://github.com/ehennestad/EBRAINS-MATLAB/actions/workflows/test-code.yml)
[![codecov](https://codecov.io/gh/ehennestad/EBRAINS-MATLAB/graph/badge.svg?token=H8GE1A76YI)](https://codecov.io/gh/ehennestad/EBRAINS-MATLAB)
[![MATLAB Code Issues](.github/badges/code_issues.svg)](https://github.com/ehennestad/EBRAINS-MATLAB/security/code-scanning)
[![Run Codespell](https://github.com/ehennestad/EBRAINS-MATLAB/actions/workflows/run-codespell.yml/badge.svg)](https://github.com/ehennestad/EBRAINS-MATLAB/actions/workflows/run-codespell.yml)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://gitHub.com/ehennestad/EBRAINS-MATLAB/graphs/commit-activity)


Lightweight MATLAB helpers and API clients for working with EBRAINS services: authentication, Data Proxy buckets, the Knowledge Graph (KG), and the Collaboratory.

## Features
- Authenticate to EBRAINS using the **device flow** or the **client credentials flow**
- List, upload, download, rename, and delete objects in Data Proxy buckets, and compute bucket sizes
- Read, create, update, release, and delete Knowledge Graph instances, and run dynamic queries
- Search collabs through the Collaboratory API

## Requirements
- MATLAB R2022b or newer
- An EBRAINS account and internet access

## Installation
Download the `.mltbx` file from the [latest release](https://github.com/ehennestad/EBRAINS-MATLAB/releases/latest) and open it in MATLAB, or install the toolbox from the [Add-On Explorer](https://se.mathworks.com/matlabcentral/fileexchange/182284-ebrains-services-toolbox).

To use the source directly, clone the repo and add `src/` to your MATLAB path:

```matlab
addpath(genpath(fullfile(pwd, "src")))
savepath  % optional
```

## Quick start

### 1) Authenticate
```matlab
ebrains.authenticate()
```
This opens a browser window that redirects to the EBRAINS login page. Scripts and CI jobs can use the client credentials flow instead:

```matlab
ebrains.authenticate(OAuthFlow="ClientCredentialsFlow", ...
    OIDCClientID="my-client", OIDCClientSecret="my-secret")
```
> [!TIP]
> You can also provide an access token via the environment variable `EBRAINS_TOKEN`.

### 2) Work with Data Proxy buckets
List objects and compute the total size of a bucket:
```matlab
objects = ebrains.bucket.listBucketObjects("my-bucket", Verbose=true);
bytes = ebrains.bucket.getBucketSize("my-bucket");
fprintf("Objects: %d, Size: %.2f GB\n", numel(objects), double(bytes)/1e9);
```

Upload, download, and delete files:
```matlab
ebrains.bucket.uploadFile("my-bucket", "results/summary.csv", "summary.csv");
ebrains.bucket.downloadFile("my-bucket", "results/summary.csv", "summary_copy.csv");
ebrains.bucket.deleteObject("my-bucket", "results/summary.csv");
```

### 3) Download Knowledge Graph metadata
```matlab
kgClient = ebrains.kg.api.InstancesClient();
instance = kgClient.getInstance("08ab00ea-3e19-4300-9d9f-c0ef0ec8e445");
```
Lookups default to the `RELEASED` stage. Pass a stage vector in order of preference to fall back to unreleased drafts:
```matlab
instance = kgClient.getInstance(identifier, ["RELEASED", "IN_PROGRESS"]);
```

### 4) Search collabs
```matlab
collabClient = ebrains.collab.api.CollabsClient();
collabs = collabClient.searchCollabs(limit=50);
```

More complete examples are in [`src/ebrains/examples`](src/ebrains/examples).

## See Also
### [openMINDS KG Sync](https://github.com/ehennestad/openminds-kg-sync)
A MATLAB toolbox that builds upon the EBRAINS MATLAB KG API to provide high-level functions for synchronizing [openMINDS](https://openminds.docs.om-i.org/en/latest/) metadata to and from the [EBRAINS Knowledge Graph](https://docs.kg.ebrains.eu). It offers convenient methods like `kglist`, `kgpull`, and `kgsave` for working with [openMINDS metadata types](https://github.com/openMetadataInitiative/openMINDS_MATLAB), handling serialization and deserialization of instances. If you need to work with structured neuroscience metadata using the openMINDS standard, this toolbox provides a streamlined interface on top of the lower-level `ebrains.kg.api.InstancesClient` functionality.

## Contributing
- Open an issue to discuss ideas/bugs.
- Fork, create a feature branch, add tests where practical, and open a PR.
