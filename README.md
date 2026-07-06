# dpm-assembly


This repository assembles and releases the SDK, including the Daml Package Manager itself (dpm) and the vetted versions of the components specified within an assembly manifest.

There are currently `unstable` and `open-source` manifests : 


## Unstable  Release Manifest
Located under `latest/unstable/<release-line>.yaml`, the assembly manifest specifies the versions of the components to be included in an unstable release matching floating tags of the relevant components at point of construction.

## Stable Release Manifest
Located under `latest/open-source/<release-line>.yaml`, the assembly manifest specifies the versions of the components to be included in the release.

## Example Manifest

```yaml
edition: open-source
version: 13.5.0-snapshot
components:
  foo:
    version: 22.5.0-snapshot.20251218.17691.0.vf1670669
  bar:
    image-tag: 35.3
  baz:
    image-tag: 22.4
    platforms:
      - linux/amd64
      - linux/arm64
      - darwin/amd64
      - darwin/arm64
      - windows/amd64
```

## Triggering an SDK release
For an `open-source` SDK release, the release is triggered by a human with pinned versions for all components. (The components that go in a given SDK release must have had already been previously published to `public`)

The process is:
- submit a PR containing changes to [latest/open-source/3.5.yaml](latest/open-source/3.5.yaml) add the `Standard Change` label onto the PR

Once approved and merged into `main`, a CI process will automatically:
- publish dpm-sdk tarball(s)
- publish the dpm sdk `sdk-manifest.yaml` to OCI
- (if needed) re-publish the components from `public-unstable` to `public`

For `unstable` SDK releases, we take releases with the latest versions of all components, in a fully automated way without the need for a human in the loop.

