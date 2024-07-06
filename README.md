**terraform-makefile**

![TF](https://img.shields.io/badge/Terraform%20Version-%3E%3D0.11.10-blue.svg)
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
- [Ack](#ack)
- [TODO](#todo)
<!--toc:end-->

## Usage

View a description of Makefile targets with help via the [self-documenting makefile](https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html).

```bash
$ make
prep                           Prepare a new workspace (environment) if needed, configure the tfstate backend, update any modules, and switch to the workspace
```

> [!NOTE]
> Before each target, several private Makefile functions run to configure the remote state backend, `validate`,`set-ws`, and `init`. You should never have to run these yourself.

### Considerations

* Each time this makefile is used, the remote state will be pulled from the GCS backend. This can result in slightly longer iteration times.
* The makefile uses `.ONESHELL`, which may not be available in all make implementations.

## License

This code is licensed under the [MIT License](LICENSE).

(C) [Serhii Prodanov](https://github.com/serpro69)

## Ack

This makefile was inspired by:

- [pgporada/terraform-makefile](https://github.com/pgporada/terraform-makefile)

## TODO

- [ ] `init`
  - ask user if they want to re-initialize the config, and only proceed with `init` on positive answer
  - with this, we can safely call `init` target from other targets, i.e. `plan` or `apply` (currently this would produce too much noise from init on each plan/apply/... command)
