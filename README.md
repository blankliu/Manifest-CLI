# Manifest-CLI
A CLI tool used to operate on manifest files of Android projects.

## Background
- For Android based projects, there are always involving lots of Git projects which are managed by a separate manifest project.
- A manifest project may contain several manifest files which are used to compose a whole Android code base.
- Operations regarding manifest files such as extracting Git project list or forking code bases with new branches are common requirements.

## Designing
A framework featured with high extensibility is used to design the implementation for this CLI tool.

#### 1. Principles of the Framework

- Every function is treated as a separate sub-command so that there is no interference exists.
- Every function has its own option list, usage document and implementation details.
- An unified entry controls the execution of each function.

## Configuration

#### 1. Download script manifest-cli.sh

```shell
mkdir $HOME/.bin
curl -Lo $HOME/.bin/manifest-cli.sh https://raw.githubusercontent.com/blankliu/Manifest-CLI/master/manifest-cli.sh
chmod a+x $HOME/.bin/manifest-cli.sh
```

#### 2. Put script manifest-cli.sh into System path

- In order to use script **manifest-cli.sh** anywhere within your Shell terminal, placing it into System path is required.

```shell
sudo ln -s $HOME/.bin/manifest-cli.sh /usr/bin/manifest-cli.sh
```

## How to Use

#### 1. Show all sub-commands implemented in this CLI tool

```shell
manifest-cli.sh --help
```

#### 2. Show usage of a sub-command

- Takes sub-command 'classify' as an example, there are two ways to show its usage

```shell
manifest-cli.sh help classify
manifest-cli.sh classify --help
```
