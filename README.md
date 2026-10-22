# Appcircle Git Mirror

This step points git at the mirrors of public git repositories on your own git server (for example GitLab, Bitbucket Data Center or Gitea), so dependencies that are cloned with git work on runners without internet access:

- CocoaPods pods with `:git`, and pods whose podspec downloads its source with git;
- Swift packages added to the Xcode project or listed in `Package.swift`;
- git submodules;
- `git:` dependencies in `pubspec.yaml` and git dependencies in `package.json`.

The step sets git configuration for the later steps of the build through environment variables (`GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_<n>`, `GIT_CONFIG_VALUE_<n>`). It writes nothing to `~/.gitconfig` or to the repository. If `AC_MIRROR_GIT` is empty, the step does nothing.

## Where to Place It

- **After Git Clone**, next to the other mirror steps, for dependencies that later steps download (CocoaPods, Swift packages, pub, npm).
- **Before Git Clone**, if your repository has submodules on the Git Source host: Git Clone then fetches them from the mirror too.

Both places work for the dependencies; the step only has to come before the steps that download them. If the app's own repository is on the Git Source host (for example on github.com), place the step after Git Clone, or Git Clone would fetch the app from the mirror too.

## Optional Input Variables

- `$AC_MIRROR_GIT`: Base URL on your git server under which the repositories of the Git Source are mirrored with the same paths. With `https://git.example.com/github/`, `https://github.com/apple/swift-log.git` is fetched from `https://git.example.com/github/apple/swift-log.git`. If empty, the step does nothing.
- Git Source (default `https://github.com/`): Base URL of the public git host whose repositories are mirrored. Its https, http, ssh and `git@host:` forms are all sent to `AC_MIRROR_GIT` over https. For a second host, add the step again with that host and its mirror URL.

Set `AC_MIRROR_GIT` once in an Environment Variable Group and add the group to the configurations that use the step.

## Access to the Mirrors

The step has no credential inputs: git reads the mirrors like any other repository on your git server.

- Mirrors on the same git server as the app's repository: the user of Appcircle's git connection must be able to read them. Git Clone caches its credentials for that server for the rest of the build, so the mirrors and private repositories next to the app (private pods or packages) use them too. This needs an HTTPS connection and Git Clone's credential caching on (the default).
- Otherwise, for example when the app is cloned over SSH: allow anonymous (public) read on the mirrors.

## What the Step Does

- Adds one `url.<AC_MIRROR_GIT>.insteadOf` rule for each form of the Git Source, and logs each rule, for example `Git Mirror: https://github.com/ -> https://git.example.com/github/`.
- Keeps rules that are already in the environment, for example from a second Git Mirror step for another host.

## Runners That Keep Their State

The rules exist only in the environment of the current build. The step writes no file on the runner.

## Mirror Setup

Mirror each repository your projects use, with its branches and tags, under one group or project namespace of its own (for example `github`), keeping the path of the source (`<owner>/<repository>`). Keep the mirrors up to date with the pull mirroring feature of your git server or a scheduled job.

To find the repositories:

- CocoaPods: the `:git` pods in `Podfile`, and the `source` of each pod's podspec that uses `:git`.
- Swift packages: `Package.resolved` (in the `.xcworkspace` or `.xcodeproj`, under `xcshareddata/swiftpm/`) lists every package, including indirect ones.
- Submodules: `.gitmodules`, including the submodules of the submodules.
- pub and npm: `git:` entries in `pubspec.yaml`, git URLs in `package.json` and the lock files.

A package that pulls submodules of its own (for example a Swift package with a submodule on github.com) needs those mirrored too. Mirrors of repositories with Git LFS need the LFS objects as well.

## Limits

- Needs git 2.31 or later on the runner (the step checks it).
- Covers tools that run git: CocoaPods, Xcode and SwiftPM, Git Clone, pub, npm. Downloads over plain HTTPS are not git: SwiftPM `binaryTarget` zips, GitHub release assets and podspecs with an `:http` source need an artifact proxy instead.
- Only the hosts you configure are redirected. A dependency on another host still goes to that host.
