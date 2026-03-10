# Student Code Coverage Instructions

There is a handy feature in `gcc` compilation that lets you track code coverage for your test cases.  It compiles extra information into the program, so when you run it, code coverage data files will be generated alongside anything your program produces.  After that, you can use a utility like `lcov` in Linux/WSL to let you analyze your program for what portions of your code were visited/run during execution, and which ones weren't. 

## Requirements

- you must be running Linux.  Windows Subsystem for Linux (WSL) works fine.
- your code must have a configuration that lets you run all your unit tests from a single command line run.
    - example: perhaps you used a `#define RUNTESTS` variable in your C code that is checked inside your `main()` and tells your program to run all unit tests instead of perform some other normal execution.
- you must install`lcov` in Linux/WSL for this to work.

### Password Reset

If has been a while since you have needed `sudo` for anything in your WSL setup, you may need to reset your password.  

If you need to reset your password, do the following:

- close out of Visual Studio Code entirely
- open `Powershell` (you can open the Start button in Windows and search 'Powershell')
- at the prompt, enter: `wsl -d ubuntu -u root` and press Enter
- you should get a funny look command prompt that ends in a `#`
- inside there, type `ls /home` which will show you your username
- set a new password by typing `passwd whatever_your_username_was` and follow the prompts
- close the window when you're done, then you can reopen VS Code and continue these instructions

## Setup for Code Coverage

- install `lcov`

```shell
sudo apt install lcov -y
```

- add `--coverage` option to your `gcc` build step, whether you are running `gcc` from the command line or you have it setup in your `.vscode/tasks.json` file

```shell
# example new gcc command
gcc -Wall -Werror --coverage -o pex3 *.c
```

- turn on any testing functionality with your `#define` variables, etc. (as applicable)
- modify `launch.json` to run your program with any testing flags enabled (as applicable)


## Generate Code Coverage

### Run Your Unit Tests with Code Coverage Enabled

- probably just running your program, like: e.g. `./pex3`
- if setup correctly, this will produce files like `pex3.gcda` in the folder where you ran your program
    - NOTE: aborts and errors like segmentation faults will prevent the code coverage files from being generated.  You must fixe those bugs first.

### Run Utilites to Analyze Code Coverage Files

1. generate the code coverage info file.

```shell
lcov --capture --directory . --output-file coverage.info
```

2. generate an HTML page for you to view your results

```shell
genhtml coverage.info --output-directory "coverage-html"
```

3. navigate into the `coverage-html` directory and open `index.html` in a browser

4. once opened, you will see a folder structure with statistics.

5. if you click on the the link, it will open another page with individual links to each file involved in your `gcc` compilation and statistics for those as well

6. summary of fields displayed

> There are two headings: Line Coverage and Function Coverage. Line Coverage counts the number of lines (and which ones) were visited/executed during the course of the program. So, when running your test harness, it is a reflection of what portion of the code your unit tests caused to run.
> 
> Here is a breakout, column-by-column, in the web page:
> - Line Coverage -- refers to the all the lines of code that were executed during the program run
>   - Total -- the total number of useful lines (i.e. lines that have actual code and not just comments) for that row
>   - Hits -- the number of useful lines that actually executed during your program run
>   - Rate -- Hits/Total, as a percentage
> - Function Coverage -- refers to all the functions that were executed during the program run
>   - Total -- the total number of defined functions for a particular row
>   - Hits -- the number of functions that were run in some form or fashion during the program run
>   - Rate -- Hits/Total, as a percentage
  
7. lastly, you can click into a specific file and see highlights for exactly which lines were run (gray/blue) and the ones that weren't (red)
   
8. review your results and use it to inform improvements in your unit testing harness!