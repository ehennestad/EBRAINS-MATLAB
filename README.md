# EBRAINS Services Toolbox for MATLAB

Lightweight MATLAB helpers and API clients to work with EBRAINS services (authentication, Data Proxy buckets, and KG metadata).

## Features
- Authenticate to EBRAINS using device flow
- List bucket objects and compute bucket sizes (Data Proxy)
- Download Knowledge Graph (KG) metadata into OpenMINDS collections
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

## Contributing
- Open an issue to discuss ideas/bugs.
- Fork, create a feature branch, add tests where practical, and open a PR.
