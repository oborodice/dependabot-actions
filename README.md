# dependabot-actions

GitHub Actions for auto-merging Dependabot PRs.

## auto-merge

Merges a Dependabot PR when its semver update type is allowed. Run it after your build and tests.

```yaml
name: Dependabot auto-merge

on:
  pull_request:

permissions:
  contents: write
  pull-requests: write

jobs:
  auto-merge:
    runs-on: ubuntu-latest
    if: github.event.pull_request.user.login == 'dependabot[bot]'
    steps:
      # Build and test here
      - uses: oborodice/dependabot-actions/auto-merge@v1
        with:
          update-types: patch,minor
```

|Input|Default|Description|
|:--|:--|:--|
|`github-token`|`${{ github.token }}`|Token used to fetch metadata and merge the PR|
|`update-types`|`patch`|Comma-separated semver update types to merge (`patch`, `minor`, `major`)|
|`merge-method`|`merge`|Merge method (`merge`, `squash` or `rebase`)|

## Development

```console
$ mise install
$ lefthook install
$ bats test
$ scripts/release.sh 1.0.0
```
