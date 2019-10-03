# pinnify
A simple, templated script to create PINN-compatible compressed tarballs and metadata from an OS disk image.


## Description

<img src="https://raw.githubusercontent.com/sakaki-/resources/master/raspberrypi/pi4/PINN-install-1.5.0.png" alt="[PINN Installer]" width="250px" align="right"/>

This is a simple script to simplify the creation of the necessary files required to distribute an existing OS image via [PINN](https://github.com/procount/PINN).

The basic workflow is as follows:
* **create** a baseline template for your OS (once only, if it does not already exist);
* **edit** that template (ditto); then
* have `pinnify` automatically **create a release** from the template and a compressed release OS image.

Subsequent releases of the same OS generally only require you repeat the last step, significantly saving time (and reducing the potential for deployment errors).

`pinnify` allows you to use **Bash variables and arithmetic** in your templates, and creates (and checksums) the PINN-compatible partition tarballs for you automatically, as will be shown below.


## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick Start Example](#quick-start-example)
- [Example Workflow](#example-workflow)
  * [Creating the Baseline OS Template](#creating-the-baseline-os-template)
  * [Editing the OS Template](#editing-the-os-template)
    - [partitions.json](#partitions.json)
    - [os.json](#os.json)
    - [os_list.json](#os_list.json)
    - [partition_setup.sh](#partition_setup.sh)
    - [Icon gentoo64.png](#icon)
    - [Slideshow and prepare_slides_vga.sh](#slideshow)
    - [Review](#review)
  * [Creating a Release](#creating-a-release)
  * [Deployment](#deployment)
  * [Subsequent Releases of the Same OS](#subsequent-releases-of-the-same-os)
- [Limitations](#limitations)
- [Uninstallation](#uninstallation)
- [Usage](#usage)
- [Feedback Welcome!](#feedback-welcome)


## Prerequisites

You must have the following tools installed on your Linux PC to run `pinnify`:
* `bash`
* `bsdtar`
* `findmnt`
* `ionice`
* `losetup`
* `sha512sum`
* `tput`
* `untar`
* `xz`

If you want to use autoupdating of the version text in the slide deck images, you'll also require:
* `exiftool`
* `convert`

Your machine should have at least 50% more free disk space than the *uncompressed* size of the OS image you intend to work with.

A PC with reasonable amount of RAM (>=16GB) will allow more parallel `xz` compression threads (when creating the derivative per-filesystem PINN tarballs), which can save significant amounts of time.


## Installation

To install locally, simply clone this repository, and then run the bundled script:

```console
$ git clone https://github.com/sakaki-/pinnify
$ cd pinnify
$ sudo ./install.sh
```


## Quick Start Example

> For simplicity, I'll assume operation as the root user (on a Linux PC, on which `pinnify` has been [installed](#installation)) in what follows.

The script comes with two exemplar OS templates bundled:

```console
# pinnify list-templates
* PINN image creator v0.0.1
* Currently installed OS templates:
   gentoo64
   gentoo64lite
```

So let's jump right in, and create a release for `gentoo64lite` (a variant of [`gentoo-on-rpi-64bit`](https://github.com/sakaki-/gentoo-on-rpi-64bit)).

First, we'll need a compressed image file for the OS, so download release `v1.5.1`:

```console
# cd /root
# wget -c https://github.com/sakaki-/gentoo-on-rpi-64bit/releases/download/v1.5.1/genpi64lite.img.xz
```

We know the kernel version is `4.19.67`, so let's create a releases directory, and build it!

```console
# mkdir -p /root/releases
# pinnify create-release gentoo64lite v1.5.1 4.19.67 /root/releases/ /root/genpi64lite.img.xz
* PINN image creator v0.0.1
* Temporarily decompressing image (may take some time)
* Mounted /root/genpi64lite.img.xz on /dev/loop0
* 2 partitions located in /dev/loop0, continuing
* Creating temporary mountpoint
* Analysing partition 'boot_gen_lite'
* Finding size of partition 'boot_gen_lite' in KiB, MiB
* Tarring up partition 'boot_gen_lite'
* Compressing tarball (may take some time)
* Analysing partition 'root_gen_lite'
* Finding size of partition 'root_gen_lite' in KiB, MiB
* Tarring up partition 'root_gen_lite'
* Compressing tarball (may take some time)
* Unmounting /dev/loop0
* Moving tarballs into /root/releases/gentoo64lite-v1.5.1
* Copying template files into /root/releases/gentoo64lite-v1.5.1
* (and updating with release metadata)
* Preparing / updating slides_vga using script
    1 image files updated
    4 image files unchanged
removed 'Slide1.png_original'
* 
* All done!
```

And that's it, the release has been created, all metadata (and even the version number on the first slide!) has been programmatically updated etc.:

```console
# tree /root/releases/gentoo64lite-v1.5.1
/root/releases/gentoo64lite-v1.5.1
├── boot_gen_lite.tar.xz
├── gentoo64lite.png
├── marketing.tar
├── os.json
├── os_list.json
├── partition_setup.sh
├── partitions.json
├── release_notes.txt
├── root_gen_lite.tar.xz
└── slides_vga
    ├── Slide1.png
    ├── Slide2.png
    ├── Slide3.png
    ├── Slide4.png
    └── Slide5.png

1 directory, 14 files
```

It can now be deployed to a webserver if desired, so PINN can use it.

The full release directory (minus the large partition tarballs `boot_gen.tar.xz` and `root_gen.tar.xz`, to save space!) may be viewed [here](https://github.com/sakaki-/pinnify/tree/master/example-workflow/gentoo64lite-v1.5.1).


## Example Workflow

Let's now dive in and look at the `pinnify` process in more depth, by running through a worked example. Here, we'll assume we want to convert v1.5.1 of the (full, not 'lite') [`gentoo-on-rpi-64bit`](https://github.com/sakaki-/gentoo-on-rpi-64bit) image, downloadable from [here](https://github.com/sakaki-/gentoo-on-rpi-64bit/releases/tag/v1.5.1).

> In what follows, I'm going to assume you are familiar with the basic PINN metadata layout. For more information on this, please see [here](https://github.com/procount/pinn/wiki/JSON-fields) and [here]().


### Creating the Baseline OS Template

Although `pinnify` already ships with a fully-filled-out `gentoo64` OS template, for explanatory purposes we'll walk through how this would be created from scratch.

Now, we know that our OS:
* has a compressed image tarball available from the [`gentoo-on-rpi-64bit`](https://github.com/sakaki-/gentoo-on-rpi-64bit) GitHub project;
* will be referred to as `gentoo64` in PINN;
* will be served from `https://isshoni.org/pinn/os/gentoo64/...`; and
* has two partitions on its image, which we'll call `boot_gen` and `root_gen`.

So we can create a new **OS template** as follows:
```console
# pinnify -f -p "boot_gen root_gen" create-template gentoo64 https://isshoni.org/pinn/os/
```

> We use `-f` here to forcibly overwrite the existing, shipped template with a fresh, 'starter' one.

In this pre-production script, such templates live in `/var/local/lib/pinnify/templates/<osname>`.

The files created by the command above are as follows:
```
# tree /var/local/lib/pinnify/templates/gentoo64
/var/local/lib/pinnify/templates/gentoo64/
├── gentoo64.png
├── os.json
├── os_list.json
├── partition_setup.sh
├── partitions.json
├── prepare_slides_vga.sh
├── release_notes.txt
└── slides_vga
    └── Slide1.png

1 directory, 8 files
```

These files may be viewed [here](https://github.com/sakaki-/pinnify/tree/master/example-workflow/gentoo64-template-phase1). They are _only_ default placeholders, and must be edited before they can be used to create releases.


### Editing the OS Template

So then, to **edit** the OS template text files, issue:
```console
# pinnify edit-template gentoo64
```

and the files

* `partitions.json`,
* `os.json`,
* `os_list.json`, 
* `partition_setup.sh`,
* `prepare_slides_vga.sh`, and 
* `release_notes.txt`

will open in an editor (by default `nano`, you can use the `-e`/`--editor` option to `pinnify` to modify this).

> It will also be necessary to update the icon and `slides_vga` placeholders; we'll return to these shortly.

Let's work through the edits we'd need to make, to prepare the template, in turn.


#### <a id="partitions.json"></a>`partitions.json`

First, the partitions description file. The 'starter' version of `partitions.json` looks as follows:
```
{
  "partitions": [
    {
      "label": "boot_gen",
      "filesystem_type": "<raw/FAT/ext4/ntfs/partclone/unformatted/swap>",
      "partition_size_nominal": $((DUMIBS[0] + 100)),
      "want_maximised": <false/true>,
      "uncompressed_tarball_size": $((DUMIBS[0])),
      "mkfs_options": "<-F 32/-O ^huge_file/etc>",
      "sha512sum": "${TARBALLSHA512S[0]}"
    }
,
    {
      "label": "root_gen",
      "filesystem_type": "<raw/FAT/ext4/ntfs/partclone/unformatted/swap>",
      "partition_size_nominal": $((DUMIBS[1] + 100)),
      "want_maximised": <false/true>,
      "uncompressed_tarball_size": $((DUMIBS[1])),
      "mkfs_options": "<-F 32/-O ^huge_file/etc>",
      "sha512sum": "${TARBALLSHA512S[1]}"
    }
  ]
}
```

As you can see, `pinnify` has already created two partition entries for us and named them `boot_gen` and `root_gen` as requested (you can specify an arbitrary number of partitions when [creating a template](#creating-the-baseline-os-template)). Notice also how some of the fields contain Bash **variable expressions**. These will be _evaluated_ by `pinnify` when creating an actual release from the template, based on values set up by analyzing the specific compressed bootable release image.

<a id="partitions-vars"></a>For the `partitions.json` file, the following variables may be used (of course, they will only be _evaluated_ when a release is made):
* `DUKIBS`, a zero-indexed numeric array variable, containing the size of each image tarball filesystem, in KiB (as reported by `du -BK`, hence the name).
* `DUMIBS`, as above, but using MiB units (rounded up).
* `TARBALLBYTES`, a zero-indexed numeric array variable, containing the size of each compressed partition tarball `pinnify` automatically creates (here, `boot_gen.tar.xz` and `root_gen.tar.xz`) in bytes.
* `TARBALLSHA512S`, a zero-indexed string array variable, containing the `sha512sum` of each of these auto-created partition tarballs (used for validity checking by PINN).

For some of the fields (such as _e.g._, `filesystem_type`) we need to explicitly edit the template, and select a specific variant. We can also add other (legitimate PINN) fields if required.

For this OS, we know our first (array index 0!) partition is `FAT32` formatted. We elect to make it - as is normal practice for a bootfs - fixed in size, in this case 255 MiB, regardless of the extent of the `boot_gen.tar.xz` tarball's contents (they'll be much smaller), and _not_ to maximize it to take up all remaining free space.

Also, we know that the second (array index 1) partition is `ext4` formatted. We elect to require at least 4GiB more than the minimal size for the partition, and to maximize the partition (and filesystem) to fill all available space.

As such, we change the OS template file `partitions.json` to look as follows:

```
{ 
  "partitions": [
    { 
      "label": "boot_gen",
      "filesystem_type": "FAT",
      "partition_size_nominal": 255,
      "want_maximised": false,
      "uncompressed_tarball_size": $((DUMIBS[0])),
      "mkfs_options": "-F 32",
      "sha512sum": "${TARBALLSHA512S[0]}"
    }
,
    { 
      "label": "root_gen",
      "filesystem_type": "ext4",
      "partition_size_nominal": $((DUMIBS[1] + 1024*4)),
      "want_maximised": true,
      "uncompressed_tarball_size": $((DUMIBS[1])),
      "mkfs_options": "-O ^huge_file",
      "sha512sum": "${TARBALLSHA512S[1]}"
    }
  ]
}
```

> You can use arbitrarily complex numeric expressions in your OS templates.


#### <a id="os.json"></a>`os.json`

Next we turn our attention to the template `os.json` file. The 'starter' version, before we edit it, looks as follows:

```
{
    "name":                     "gentoo64",
    "description":              "<Description here, can include ${RELEASE}>",
    "release_date":             "${RELDATE}",
    "feature_level":            0,
    "supported_models": [
        "Pi 3 Model B Rev",
        "Pi 3 Model B Plus Rev",
        "Pi 3 Model A Plus Rev",
        "Pi 4 Model B Rev"
    ],
    "version":                  "${RELEASE}",
    "kernel":                   "${KERNEL}",
    "supports_backup":          "<true/false/update>",
    "url":                      "<URL>",
    "group":                    "<General/Minimal/Education/Media/Utitlity/Games>",
    "username":                 "<default_username>",
    "password":                 "<default_password>",
    "sha512sum":                "${PSSHA512}"
}
```

<a id="os-vars"></a>We have the following variables available to us here:
* `RELEASE`, a string variable containing the release name (e.g. `v1.5.1`, `v1.5.2` etc.).
* `RELDATE`, a string variable containing the release date, in "YYYY-MM-DD" format.
* `KERNEL`, a string variable containing the kernel's specification (e.g. `14.19.67`).
* `PSSHA512`, a string variable containing the `sha512sum` of `partition_setup.sh`.
* `TOTALNOMINALMIB`, a numeric variable containing the sum of all `partition_size_nominal` fields from [`partitions.json`](#partitions.json).

Again, we fill this out with OS-specific information (description, default user name, supported models etc.), to yield the following final version:

```
{
    "name":                     "gentoo64",
    "description":              "64-bit Gentoo Linux ${RELEASE} for the RPi4 and RPi3, with Xfce4 desktop",
    "release_date":             "${RELDATE}",
    "feature_level":            0,
    "supported_models": [
        "Pi 3 Model B Rev",
        "Pi 3 Model B Plus Rev",
        "Pi 3 Model A Plus Rev",
        "Pi 4 Model B Rev"
    ],
    "version":                  "${RELEASE}",
    "kernel":                   "${KERNEL}",
    "supports_backup":          "update",
    "url":                      "https://github.com/sakaki-/gentoo-on-rpi-64bit",
    "group":                    "General",
    "username":                 "demouser",
    "password":                 "raspberrypi64",
    "sha512sum":                "${PSSHA512}"
}
```

One field that is perhaps not self-evident here is `supports_backup`. Its value depends on whether the target OS' `partition_setup.sh` script (see [below](#partition_setup.sh)) can restore the OS from a PINN backup or not.
* If it can (and always has been since its first version released on PINN), use `true`.
* If it cannot, or your OS cannot be straightforwardly backed up (`btrfs` filesystem etc.), use `false`.
* If it can restore now, but some older (PINN-released) versions could not, use (the string value) `"update"`. It is safe to use `"update"` in place of `true`.

#### <a id="os_list.json"></a>`os_list.json`

Now we come to `os_list.json`. This is not a file directly required by PINN, but goes as a list entry into the portmanteau `os_list_v3.json` top-level repository metadata file.

The 'starter' version in the OS template looks as follows:

```
        {
            ${OSJSONDATA},
            "download_size":            $((TOTALTARBALLBYTE)),
            "os_info":                  "https://isshoni.org/pinn/os/gentoo64/os.json",
            "partitions_info":          "https://isshoni.org/pinn/os/gentoo64/partitions.json",
            "icon":                     "https://isshoni.org/pinn/os/gentoo64/gentoo64.png",
            "marketing_info":           "https://isshoni.org/pinn/os/gentoo64/marketing.tar",
            "partition_setup":          "https://isshoni.org/pinn/os/gentoo64/partition_setup.sh",
            "tarballs": [
                "https://isshoni.org/pinn/os/gentoo64/boot_gen.tar.xz",
                "https://isshoni.org/pinn/os/gentoo64/root_gen.tar.xz"
            ],
            "nominal_size": $((TOTALNOMINALMIB))
        }
```

<a id="os_list-vars"></a>We have the following variables available to us here:
* `RELDATE`, `RELEASE`, `KERNEL`, `TOTALNOMINALMIB`, as [above](#os-vars).
* `OSJSONDATA`, a string variable containing the relevant fields filtered from [`os.json`](#os.json) (note that the `name` key will automatically be replaced with `os_name`).
* `TOTALDUKIB`, the sum of all `DUKIBS` entries (see [above](#partitions-vars)).
* `TOTALDUMIB`, the sum of all `DUMIBS` entries (see [above](#partitions-vars)).
* `TOTALTARBALLBYTE`, the sum of all `TARBALLBYTES` entries (see [above](#partitions-vars)).

As it happens, in this case we _don't_ need to modify the 'starter' version, as all fields are already correctly filled out (including the URLs, which `pinnify` has already expanded, from the base URL passed when we used `create-template` earlier).


#### <a id="partition_setup.sh"></a>`partition_setup.sh`

PINN uses this script to ensure that e.g. UUID-based partition names used in `/boot/cmdline.txt` on the bootfs, `/etc/fstab` etc. on the rootfs still work correctly. The default script provided is just the one from Raspbian Full:

```bash
#!/bin/sh
#supports_backup in PINN

# This is just the default partition_setup.sh from Raspbian Full
# Adapt as appropriate

set -ex

# shellcheck disable=SC2154
if [ -z "$part1" ] || [ -z "$part2" ]; then
  printf "Error: missing environment variable part1 or part2\n" 1>&2
  exit 1
fi

mkdir -p /tmp/1 /tmp/2

mount "$part1" /tmp/1
mount "$part2" /tmp/2

<--- snip --->

umount /tmp/1
umount /tmp/2
```

This will probably need to be edited for your OS. In the case of `gentoo64`, we change it to:

```bash
#!/bin/sh
#supports_backup in PINN

set -ex

if [ -z "$part1" ] || [ -z "$part2" ]; then
  printf "Error: missing environment variable part1 or part2\n" 1>&2
  exit 1
fi

mkdir -p /tmp/1 /tmp/2

mount "$part1" /tmp/1
mount "$part2" /tmp/2

#update root partition ref in cmdline.txt
sed /tmp/1/cmdline.txt -i -e "s|root=[^ ]*|root=${part2}|"

#Update partition refs in fstab
sed /tmp/2/etc/fstab -i -e "s|\t| |g"
sed /tmp/2/etc/fstab -i -e "s|^[^#].* / |${part2}  / |"
sed /tmp/2/etc/fstab -i -e "s|^[^#].* /boot |${part1}  /boot |"


if [ -z $restore ]; then
  # (This section only entered on initial install, not on a reinstall)
  #Hide /Settings from gentoo filemanager by mounting it 'noauto'
  mkdir -p /tmp/2/mnt/Settings
  len=${#part2}
  c2=`echo $part2 | cut -c$len`
  let len-=1
  c1=`echo $part2 | cut -c$len`
  let len-=1

  if [ $c1 == "1" -o $c1 == "2" ]; then
          c1="0"
  fi
  if [ ${part2:0:4} != "PART" -a $c1 == "0" ]; then
          c1=""
  fi
  c2="5"
  part3=${part2:0:$len}$c1$c2
  echo "${part3} /mnt/Settings ext4 defaults,noatime,noauto 0 0" >>/tmp/2/etc/fstab

  #Prevent root partition expansion - already done by PINN
  mv /tmp/1/autoexpand_root_partition /tmp/1/autoexpand_root_none #Keeps timestamp
fi


#Modify last shutdowntime (if necessary) to prevent fsck on first boot
datelt()
{
        # remove everything but digits from input parameters
        local D1=`echo $1 | tr -cd "[:digit:]"`
        local D2=`echo $2 | tr -cd "[:digit:]"`
        local D1DATE="${D1:0:8}"
        local D2DATE="${D2:0:8}"
        local D1TIME="${D1:8:4}" # ignore trailing 4 digits (timezone?)
        local D2TIME="${D2:8:4}"
        [ $D1DATE -lt $D2DATE ] || [ $D1DATE -eq $D2DATE -a $D1TIME -lt $D2TIME ]
        #0 means D1<D2  
}


file=/tmp/2/lib/rc/cache/shutdowntime
file2=/tmp/2/lib64/rc/cache/shutdowntime

timeNow=`date -Iminutes`
timeLastWrite=`date -Iminutes -r $file`
timeLastWrite2=`date -Iminutes -r $file2`
#if shutdowntime is less than time now, then update the file's timestamp to now
datelt $timeLastWrite $timeNow && touch $file
datelt $timeLastWrite2 $timeNow && touch $file2

umount /tmp/1
umount /tmp/2

```

> Note how the `$restore` variable is checked in the above. This is unset on initial install, and set when a backed-up OS is being reinstalled or restored over an existing installation, and during PINN's "fix - rerun partition_setup" action. As such, it may be used to prevent one-time operations in `partition_setup.sh` being run a second time.


#### `release_notes.txt`

There are two different ways to approach this file in the OS template:
1. If the text is specific to each release _only_, then leave it empty in the template, and just fill it out in the release directory each time afresh.
1. However if, as here, the text _grows_ with each release, then it makes sense to edit the template each time, top-posting the new content. As such we place the following in that file (shortened here for brevity):

```
Release v1.5.1
--------------

This is a bugfix release to v1.5.0. If you are already on v1.5.0, you can upgrade by following the instructions below (or wait for the automated weekly update to do this for you; note however, that due to a required genup upgrade during this process, it will take two weekly runs to fully update your system, so you may wish to follow the manual route anyway to speed things along).

Changes in this release (see main project page for further details):

<--- snip --->

[2] Once ffmpeg has the necessary v4l2 m2m codec support built in (which the version on the image has) then exploiting these features from the command line is trivial - see for example the CLI 'recipes' in this project's open wiki.

sakaki@deciban.com
```


#### <a id="icon"></a>Icon `gentoo64.png`

`pinnify` has placed a 'starter' 40x40 icon in the template directory, and named it `gentoo64.png` for us. The default icon is:

![Starter Icon](https://raw.githubusercontent.com/sakaki-/pinnify/master/example-workflow/gentoo64-template-phase1/gentoo64.png)

We replace this with a more appropriate one, leaving the name the same:

![Actual Icon](https://raw.githubusercontent.com/sakaki-/pinnify/master/example-workflow/gentoo64-template-phase2/gentoo64.png)

#### <a id="slideshow"></a>Slideshow `slides_vga/Slide<...>.png`, and `prepare_slides_vga.sh`

This folder contains the graphics shown to the user as PINN is downloading and installing the OS. By default we just have a single placeholder graphic in here, so we replace it with 7 more relevant slides (each of the recommended dimension 387x292 pixels). Note that we have left a space in the first slide for the version number:

![Slide 1 with Space for Version](https://raw.githubusercontent.com/sakaki-/pinnify/master/example-workflow/gentoo64-template-phase2/slides_vga/Slide1.png)

That's because `pinnify` provides that a simple script, `prepare_slides_vga.sh` will be run (if present) whenever a release is made. This script is invoked _inside_ the (release copy of the) `slides_vga` directory, and is passed `$VERSION` as its only argument.

Here, we edit the script so it will programmatically add the version text into the gap we've (conveniently ^-^) left on the first slide, using the correct font etc. where possible, and then strip all EXIF metadata from the slides in the deck:

```bash
#!/bin/bash

# This script will be called before tarring up the slides_vga directory
# A single argument (the release string) will be passed, and the working
# directory will be inside slides_vga
#
# You can use this to e.g. programmatically set a version number
# in one or more of your slides

# A simple example from gentoo-on-rpi-64bit follows
if true; then
    if which convert &>/dev/null && which exiftool &>/dev/null; then
        F="/usr/share/fonts/liberation-fonts/LiberationSans-BoldItalic.ttf"
        FC=""
        [[ -e "${F}" ]] && FC="-font ${F}" ||
                echo "Please install LiberationSans-BoldItalic.ttf for best results" >&2
        convert -pointsize 12 -fill black \
                ${FC} \
                -draw 'text 150,253 "Release '"${1}"'"' \
                Slide1.png Slide1.png
        # make sure no metadata leaks
        exiftool -all= *.png
        rm -vf *original
    else
        echo "Can't update slide: please ensure convert and exiftool are installed" >&2
    fi
fi
```


#### Review

With that done, our OS template creation for `gentoo64` is now complete! We can re-use this template any time we want to release a new version of this OS for PINN.

The completed OS template file tree now looks like this:

```console
# tree /var/local/lib/pinnify/templates/gentoo64/
/var/local/lib/pinnify/templates/gentoo64/
├── gentoo64.png
├── os.json
├── os_list.json
├── partition_setup.sh
├── partitions.json
├── prepare_slides_vga.sh
├── release_notes.txt
└── slides_vga
    ├── Slide1.png
    ├── Slide2.png
    ├── Slide3.png
    ├── Slide4.png
    ├── Slide5.png
    ├── Slide6.png
    └── Slide7.png

1 directory, 14 files
```

and may be reviewed [here](https://github.com/sakaki-/pinnify/tree/master/example-workflow/gentoo64-template-phase2).


### Creating a Release

Now we have a template, `pinnify` can easily make a release for us! We just need the compressed OS image file, here `genpi64.img.xz` from [`gentoo-on-rpi-64bit`](https://github.com/sakaki-/gentoo-on-rpi-64bit). We download this in `/root/`:

```console
# cd /root
# wget -c https://github.com/sakaki-/gentoo-on-rpi-64bit/releases/download/v1.5.1/genpi64.img.xz
```

We know that the release name is `v1.5.1`, and it uses kernel `4.19.67`.

So, let's just double-check we have a top-level `releases` directory available, and then create a PINN-compatible release!

```console
# mkdir -p /root/releases
# pinnify create-release gentoo64 v1.5.1 4.19.67 /root/releases/ /root/genpi64.img.xz
```

> There's no need to specify a release date (although you can if you wish): `pinnify` will infer it from the last modification date of the given compressed OS image.

When a `create-release` command is given, `pinnify` will unpack the image file (`genpi64.img.xz` here) into a temporary directory (this will take some time), and loop-mount it read-only. It will then iterate through the image's partitions, mounting each one read-only in turn, computing some metadata (such as total size of the filesystem), then bundling up its contents into a PINN-compatible tarball, which will automatically be `xz`-compressed (this will also take some time). The size and `sha512sum` of each such compressed tarball will also be captured.

> All temporary working directories are deleted once `pinnify` exits.

Next, `pinnify` creates a new directory for the release (here, `/root/releases/gentoo64-v1.5.1`) and moves the compressed partition tarballs just created into it. It also copies across files from the OS template that we just set up, _substituting for the various metadata variables, and evaluating any Bash numeric expressions, as it does so_. The result is that we have the following release directory:

```console
# tree /root/releases/gentoo64-v1.5.1
/root/releases/gentoo64-v1.5.1
├── boot_gen.tar.xz
├── gentoo64.png
├── marketing.tar
├── os.json
├── os_list.json
├── partition_setup.sh
├── partitions.json
├── release_notes.txt
├── root_gen.tar.xz
└── slides_vga
    ├── Slide1.png
    ├── Slide2.png
    ├── Slide3.png
    ├── Slide4.png
    ├── Slide5.png
    ├── Slide6.png
    └── Slide7.png

1 directory, 16 files
```

Let's look at how each of the files has been transformed. First `partitions.json`:

```json
{
  "partitions": [
    {
      "label": "boot_gen",
      "filesystem_type": "FAT",
      "partition_size_nominal": 255,
      "want_maximised": false,
      "uncompressed_tarball_size": 61,
      "mkfs_options": "-F 32",
      "sha512sum": "41553d27add53908cd4ef37aafe6ea8963d4221032cea8138d96632297d2db68301cd9c27a2edbb77c1b340569f8dbc0ce398fd20ac6f7a1e75f6a53b5c95734"
    }
,
    {
      "label": "root_gen",
      "filesystem_type": "ext4",
      "partition_size_nominal": 13419,
      "want_maximised": true,
      "uncompressed_tarball_size": 9323,
      "mkfs_options": "-O ^huge_file",
      "sha512sum": "89ccdc658b4f3193451956719fb42b2c06aeb5e55d4461423ba3a13415c0059982fbf7997f51bcfba373110fe74025ed534fc05b477563cb8b1075782b62d981"
    }
  ]
}
```

Notice how the sizes fields have been automatically filled out following our template formulae, as have the `sha512sum`s for the two partition tarballs (`boot_gen.tar.xz` and `root_gen.tar.xz`).

The `os.json` file has also been completed for us:

```json
{
    "name":                     "gentoo64",
    "description":              "64-bit Gentoo Linux v1.5.1 for the RPi4 and RPi3, with Xfce4 desktop",
    "release_date":             "2019-09-01",
    "feature_level":            0,
    "supported_models": [
        "Pi 3 Model B Rev",
        "Pi 3 Model B Plus Rev",
        "Pi 3 Model A Plus Rev",
        "Pi 4 Model B Rev"
    ],
    "version":                  "v1.5.1",
    "kernel":                   "4.19.67",
    "supports_backup":          "update",
    "url":                      "https://github.com/sakaki-/gentoo-on-rpi-64bit",
    "group":                    "General",
    "username":                 "demouser",
    "password":                 "raspberrypi64",
    "sha512sum":                "5a309f616a016ed509e50a49b64461392b755ee45c3bdf1acb142811e3dab7a88b146a76543e362d039d188cff9b2664ac7d09efa15a71f381b5cc4ea1b6006f"
}
```

You can see that the release date, version etc. has been filled out, as has the `sha512sum` of the `partition_setup.sh` script.

Finally, `os_list.json`:

```json
        {
            "os_name":                  "gentoo64",
            "description":              "64-bit Gentoo Linux v1.5.1 for the RPi4 and RPi3, with Xfce4 desktop",
            "release_date":             "2019-09-01",
            "feature_level":            0,
            "supported_models": [
                "Pi 3 Model B Rev",
                "Pi 3 Model B Plus Rev",
                "Pi 3 Model A Plus Rev",
                "Pi 4 Model B Rev"
            ],
            "supports_backup":          "update",
            "url":                      "https://github.com/sakaki-/gentoo-on-rpi-64bit",
            "group":                    "General",

            "download_size":            1662150980,
            "os_info":                  "https://isshoni.org/pinn/os/gentoo64/os.json",
            "partitions_info":          "https://isshoni.org/pinn/os/gentoo64/partitions.json",
            "icon":                     "https://isshoni.org/pinn/os/gentoo64/gentoo64.png",
            "marketing_info":           "https://isshoni.org/pinn/os/gentoo64/marketing.tar",
            "partition_setup":          "https://isshoni.org/pinn/os/gentoo64/partition_setup.sh",
            "tarballs": [
                "https://isshoni.org/pinn/os/gentoo64/boot_gen.tar.xz",
                "https://isshoni.org/pinn/os/gentoo64/root_gen.tar.xz"
            ],
            "nominal_size": 13674
        }
```

Again note how the relevant fields from `os.json` have been transcluded, and values such as the total download size substituted.

Note also that the `slides_vga` directory has been tarred up, per PINN's requirements, into `marketing.tar`, and that `Slide1.png` has had the version stamped on (by the `prepare_slides_vga.sh` script), thus:

![Slide 1 with Substituted Version](https://raw.githubusercontent.com/sakaki-/pinnify/master/example-workflow/gentoo64-v1.5.1/slides_vga/Slide1.png)

The full release directory (minus the large partition tarballs `boot_gen.tar.xz` and `root_gen.tar.xz`, to save space!) may be viewed [here](https://github.com/sakaki-/pinnify/tree/master/example-workflow/gentoo64-v1.5.1).


### Deployment

To deploy on your webserver, simply copy the contents of the release directory into the appropriate location; for example:
```console
# mv /var/www/pinn/os/gentoo64{,.old}
# cp -r /root/releases/gentoo64-v1.5.1 /var/www/pinn/os/gentoo64
```

and then edit the contents of your `os_list_v3.json` file to include the new `os_list.json` from the release directory. For example:

```
{
    "os_list": [
        {
            "os_name":                  "gentoo64",
            "description":              "64-bit Gentoo Linux v1.5.1 for the RPi4 and RPi3, with Xfce4 desktop",
            "release_date":             "2019-09-01",
            "feature_level":            0,
            "supported_models": [
                "Pi 3 Model B Rev",
                "Pi 3 Model B Plus Rev",
                "Pi 3 Model A Plus Rev",
                "Pi 4 Model B Rev"
            ],
            "supports_backup":          "update",
            "url":                      "https://github.com/sakaki-/gentoo-on-rpi-64bit",
            "group":                    "General",

            "download_size":            1662150980,
            "os_info":                  "https://isshoni.org/pinn/os/gentoo64/os.json",
            "partitions_info":          "https://isshoni.org/pinn/os/gentoo64/partitions.json",
            "icon":                     "https://isshoni.org/pinn/os/gentoo64/gentoo64.png",
            "marketing_info":           "https://isshoni.org/pinn/os/gentoo64/marketing.tar",
            "partition_setup":          "https://isshoni.org/pinn/os/gentoo64/partition_setup.sh",
            "tarballs": [
                "https://isshoni.org/pinn/os/gentoo64/boot_gen.tar.xz",
                "https://isshoni.org/pinn/os/gentoo64/root_gen.tar.xz"
            ],
            "nominal_size": 13674
        }
        ,
        {
            "os_name":                  "gentoo64lite",
            <--- snip --->
            "nominal_size": 7418
        }
        ,
        {
            "os_name":	       "nspawn64",
            <--- snip --->
            "nominal_size": 5066
        }
    ]
}
```


### Subsequent Releases of the Same OS

Making a new release of an OS for which you have an compressed image file (and an already-set-up OS template) is very straightforward!

For example, to create a `v1.5.2` of `gentoo64`, with e.g. kernel `4.19.69`, and assuming the image file was available at `/root/new/genpi64.img.xz`, you'd simply issue:
```console
# pinnify create-release gentoo64 v1.5.2 4.19.69 /root/releases/ /root/new/genpi64.img.xz
```

Edit the release notes, then deploy as before. Done!

You can have multiple OS templates in use at the same time - they do not interfere with each other.


## Limitations

The current script can only deal with images that are XZ or Zip compressed. This is relatively straightforward to extend.

It also does no sanity checking of the final release directory once created.


## Uninstallation

To uninstall, simply enter the repository's directory, and then run the bundled script:

```console
$ cd pinnify
$ sudo ./uninstall.sh
```

**Caution:** uninstalling will also remove any OS-templates you have created or edited (although it will *not* remove releases).


## Usage

```console
# pinnify -h
pinnify - create PINN compressed tarballs & metadata from bootable image
Usage: pinnify <options> [command] [command_args]

e.g.

pinnify list-templates
pinnify -p "boot_gen root_gen" create-template gentoo64 https://isshoni.org/pinn/os/
pinnify edit-template gentoo64
pinnify create-release gentoo64 v1.5.0 4.19.66 /root/releases/ genpi64.img.xz


Options:
  -a, --ask             turns on interactive mode: you must confirm key actions
  -A, --alert           sound terminal bell when interaction required
                        (selecting this also automatically selects --ask)
  -B, --no-bracket-check
                        don't check for "< or >" in OS template files
  -e, --editor=E        set the editor to be E (default nano)
  -f, --force           force operation, even where existing files would be
                        overwritten
  -h, --help            show this help message and exit
  -p, --partnames       specify partition names (as a space separated list)
                        defaults to "boot root" if not specified
  -r, --adjustment=N    add N to niceness of CPU-intensive ops; -20<=N<=19
                        (the default is 19, operating at lowest possible
                        system priority to avoid slowing the system too much)
  -v, --verbose         ask called programs to display more information
  -V, --version         display the version number of pinnify and exit
  -w, --workdir=DIR     set top level working directory to be DIR; defaults to
                        /var/lib/pinnify

Commands:
  list-templates        list currently defined OS templates
  create-template OSNAME BASEURL
                        create an editable template for an OS in
                        /var/local/lib/pinnify/templates
                        containing os.json, os_list.json, and partitions.json
                        plus skeleton partition_setup.sh,
                        prepare_slides_vga.sh, release_notes.txt
                        OSNAME.png and slides_vga/ directory
                        served from BASEURL/OSNAME/...
  edit-template OSNAME  open the above files using the default editor
                        (specify with -e/--editor)
  create-release OSNAME RELEASE KERNEL BASEDIR IMAGE <RELDATE>
                        create a release for the specified  using the
                        pre-created template, plus the given IMAGE, and
                        save it into BASEDIR/OSNAME-RELEASE/...
                        the release is RELEASE, kernel version KERNEL
                        you may also specify RELDATE (YYYY-MM-DD); if not
                        given, the last modification date of IMAGE
                        will be used
```


## Feedback Welcome!

If you have any problems, questions or comments regarding this project, feel free to drop me a line! (sakaki@deciban.com)
