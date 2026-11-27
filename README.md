# flux
A fast, multi-threaded download manager written in Fish shell. With this, you can download files faster!

## You need fish to use this script:

## Installing Fish
Debian:
```bash
sudo apt install fish
```

Fedora:
```bash
sudo dnf install fish
```

Arch Linux:
```bash
sudo pacman -S fish
```

You still need to install these:

## Installing curl:

Debian:
```bash
sudo apt install curl
```

Fedora:
```bash
sudo dnf install curl
```

Arch Linux:
```bash
sudo pacman -S curl
```

## Installing flock:
Debian:
```bash
sudo apt install util-linux
```

Fedora:
```bash
sudo dnf install util-linux
```

Arch Linux:
```bash
sudo pacman -S util-linux
```

## Usage:

Make it executable:
```bash
chmod +x flux.fish
```

You can install the script to easily access `flux` from the terminal from anywhere. This is recommended:

Install:
```bash
./flux.fish -i
```

Execute:
```bash
flux
```

It will ask for a URL that points to a file. Make sure that the URL ends with a filename. For example, you can obtain this link by right-clicking on a download button and selecting "copy link."

Then it asks which folder the file should be placed in.

After that, it asks how many threads the download should use. The default and recommended number is 8. There is no point in setting it higher than 16.

Then it downloads the file. In most cases, faster than a standard browser would.

## How does it work???
It divides the file to be downloaded into 8 MB segments (chunks) and downloads these simultaneously using 8 threads (or however many threads have been configured). (In a browser, by contrast, a single thread downloads the entire file.) Why divide the file into 8 segments, or a number of segments corresponding to the number of threads? Because if a thread finishes its task, it would otherwise be left with nothing to do (even though work might still be available). With this approach, however, there is a large queue of 8 MB chunks, ensuring that there is almost always work to be done. Consequently, the download speed does not drop significantly toward the end (i.e., after 85% of the total file has been downloaded).

## About
This code was written by Zoárd Gódor