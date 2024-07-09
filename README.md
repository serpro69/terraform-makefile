**terraform-makefile**

![TF](https://img.shields.io/badge/Terraform%20Version-%3E%3D1.0.0-purple.svg)
[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)

## About

This is my [terraform](https://www.terraform.io/) workflow for every terraform project that I use personally/professionaly when working with Google Cloud Platform.

## TOC

<!--toc:start-->
- [About](#about)
- [TOC](#toc)
- [Usage](#usage)
  - [Considerations](#considerations)
- [License](#license)
- [Contribute](#contribute)
- [Ack](#ack)
- [TODO](#todo)
<!--toc:end-->

## Usage

View a description of Makefile targets with `help` via the [self-documenting makefile](https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html).

```text
➜ make
This Makefile provides opinionated targets that wrap terraform commands with sane defaults,
initialization shortcuts for terraform environment, and a GCS terraform backend.

Usage:
> GCP_PROJECT=demo WORKSPACE=demo make init
> make plan

Tip: Add a <space> before the command if it contains sensitive information, to keep it from bash history!

Available commands:

apply                          Set course and full speed ahead! ⛵ This will cost you! 💰
clean                          Nuke local .terraform directory! 💥
destroy                        Release the Kraken! 🐙 This can't be undone! ☠️
format                         Swab the deck and tidy up! 🧹
help                           Save our souls! 🛟
init                           Hoist the sails and prepare for the voyage! 🌬️💨
lint                           Inspect the rigging and spot any issues! 🔍
plan-destroy                   What would happen if we blow it all to smithereens? 💣
plan                           Chart the course before you sail! 🗺️

Available input variables:

<WORKSPACE>                    󱁢 terraform workspace to switch to
<GCP_PROJECT>                  󱇶 google cloud platform project name
<GCP_BASENAME>                 󰾺 basename to use in other variables, e.g. short company name
<QUOTA_PROJECT>                 google cloud platform quota project name
```

> [!NOTE]
> Before each target, several private Makefile functions run to configure the remote state backend: `validate`,`set-env`, and `init`. You should never have to run these yourself.

### Considerations

* Each time this makefile is used, the remote state will be pulled from the GCS backend. This can result in slightly longer iteration times.
* The makefile uses `.ONESHELL`, which may not be available in all make implementations.

## License

This code is licensed under the [MIT License](LICENSE).

(C) [Serhii Prodanov](https://github.com/serpro69)

## Contribute

So, you've made it this far 🤓 Congrats! 🎉
I've made this makefile to simplify my own workflow when dealing with Terraform and GCP, but I'm happy if you've found this makefile useful as well.
If you want to contribute anything: fixes, new commands, customizable configuration, documentation; like, literally, anything - you should definitely do so.

Steps:

- Open a new issue (Totally optional. I'll accept PR's w/o having an open issue, so long as it's clear what the change is all about.)
- Fork this repository 🍴
- Install dependencies (I guess you already have `make` installed? 🤨)
- Bang your head against the keyboard from frustration 😡😤🤬 (Who said coding was easy?)
- Open a pull request once you're finished 😮‍💨
- Profit 🤑

## Ack

This makefile was inspired by:

- [pgporada/terraform-makefile](https://github.com/pgporada/terraform-makefile)

## TODO

- [ ] `init`
  - ask user if they want to re-initialize the config, and only proceed with `init` on positive answer
  - with this, we can safely call `init` target from other targets, i.e. `plan` or `apply` (currently this would produce too much noise from init on each plan/apply/... command)
