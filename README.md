# README

## Setup

- [Install dependencies for `gh` CLI tool](https://github.com/cli/cli/blob/trunk/README.md)
- Login on local terminal with `gh auth login`
- Install GitHub Classroom extension with `gh extension install github/gh-classroom`
- Install other required tools: lcov and genhtml with `sudo apt install lcov`

## Usage

Several variables need to be set.  The defaults will work pretty reliably for CS 220 PEX 3 with just running it and it will prompt for needed variables.

Get the assignment ID for the batch to run the code coverage tool

`gh classroom assignments`

then find the assignment ID for the respective assignment and export the `ASSIGNMENT_ID` variable in `bash`

`export ASSIGNMENT_ID=123456`

## TODO

- [ ] add conditional logic for case when there is no filter on file or just a specific .c file (patterns okay)