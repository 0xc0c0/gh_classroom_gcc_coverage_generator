# Placeholder README File

## Setup

- [Install dependencies for `gh` CLI tool](https://github.com/cli/cli/blob/trunk/README.md)
- Login on local terminal with `gh auth login`
- Install GitHub Classroom extension with `gh extension install github/gh-classroom`
- Install other required tools: lcov and genhtml with `sudo apt install lcov`

## Usage

You will need some data before the script will run successfully.  Note the default variables section in the primary script file.

This script was initially designed for CS 220 PEX 3.

Get the assignment ID for the batch to run the code coverage tool

`gh classroom assignments`

then find the assignment ID for the respective assignment and export the `ASSIGNMENT_ID` variable in `bash`

`export ASSIGNMENT_ID=123456`