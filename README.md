# Tools - WordPress

David Williamson @ Varilink Computing Ltd

------

This repository provides tooling for the development and testing of WordPress sites. It does this by defining Docker Compose services that run any WordPress based website on the desktop, along with integration with the WP-CLI command-line interface for WordPress that is also supplemented with various helper functions.

## Contents

| File/Directory       | Description                                            |
| -------------------- | ------------------------------------------------------ |
| `docker-compose.yml` | Docker Compose project configuration.                  |
| `wp-cli/`            | Artefacts used by the `wp-cli` Docker Compose service. |

## Usage

### Installing this tool within a WordPress site project

1. Add this repository as a submodule of a project that uses it. This must be at the path `tools/wordpress/` relative to the root folder of that master project.

2. Set the following Docker Compose environment variables in the project:
   - COMPOSE_PROJECT_NAME
   - WORDPRESS_TAG
   - MARIADB_TAG

3. Add any additional Docker Compose files to your project that you require in order to extend the services defined in this repository; for example in order to pass through project specific environment variables.

4. Be sure to apply all the required Docker Compose files in the right order, which can be done using the COMPOSE_FILE environment variable for convenience. Note that you must include a Docker Compose file in the project's root folder **first** in the `COMPOSE_FILE` variable since this then sets the root folder for any relative paths in all the subsequent Docker Compose files - see [this issue on GitHub](https://github.com/docker/compose/issues/3874), which identifies the workaround of using an empty Docker Compose file in the project's root folder where there isn't already one in there that can be referenced first.

5. To make the project's WordPress website available in the web browser on the desktop, also add the Varilink Computing Ltd [tools-proxy](https://github.com/varilink/tools-proxy) repository as a submodule of the master project. Usage help for that tool can be found in [tools-proxy/README.md](https://github.com/varilink/tools-proxy/blob/main/README.md).

Good examples of this tool being used in projects can be found in my [FoBV - Docker](https://github.com/varilink/fobv-docker) and [Website - Docker](https://github.com/varilink/website-docker) repositories.

### Starting a project from scratch

When starting work on a project for the first time, with no existing project containers or volumes in place, simply bring the project's `wordpress` service up via `docker-compose up wordpress`. You will then be able to run the WordPress installation script for your development website at `http://${COMPOSE_PROJECT_NAME}` in a web browser on your desktop, provided you have the right proxy port mapping in place - see [tools-proxy/README.md](https://github.com/varilink/tools-proxy/blob/main/README.md).

In this mode it's probable that you won't need to provide any project overrides for the Docker Compose services provided by this tool. As noted above however, the Docker Compose file listed first in the `COMPOSE_FILE` must be a project file in the project's root folder. As highlighted in the GitHub issue referenced above, this can be achieved using a Docker Compose file that is empty, save for the Docker Compose file version number; for example:

```yaml
version: '3.9'
```

The `docker-compose.yml` files that come with Docker Compose based Varilink Computing Ltd tools, including this one, do **not** specify a version number. If you do configure any service overrides in the project's master Docker Compose file, then the version can be omitted from that file also. Docker seems to infer the version from the syntax of the service definitions.

The WordPress installation folder is stored in a volume named *wordpress*, which will be created with the name `${COMPOSE_PROJECT_NAME}_wordpress`. This is because it is shared by both the wordpress and wp-cli Docker Compose services. Be alert that this means it must be explicitly removed if that's required. It can't be cleared by simply removing a container.

### Restoring a project from backup

You can restore a WordPress website from backup to work on updates to it locally. There are two aspects to this, the database and the WordPress files.

To enable this you must map directories that hold the backup files to the correct paths within the containers for the *db* and/or the *wp-cli* Docker Compose services. You can do this via the `--volume` option of the `docker-compose` command, as a one-off, or extend the *db* and/or *wp-cli* services defined in this tool's `docker-compose.yml` file in your project's own `docker-compose.yml` file. I would recommend the latter approach as the continuation of the volume mappings being in place after you've used them to restore from causes no issues.

The details of how this works for each of the *db* and *wp-cli* services are as follows:

- For the *db* service, a volume that maps a directory containing a database dump file to restore from must be mapped to the directory `/docker-entrypoint-initdb.d` in the container. That directory is as expected by mariadb official image hosted by Docker Hub - see under "Initializing the database contents" on [Docker Hub's mariadb image page](https://hub.docker.com/_/mariadb).

  As per the documentation on that page, the mariadb image "will execute files with extensions `.sh`, `.sql`, `.sql.gz`, `.sql.xz` and `.sql.zst` that are found in `/docker-entrypoint-initdb.d`. Once the backup has been used to restore from it will be ignored when you subsequently bring the *db* service up again until such time as you remove the container.

- For the *wp-cli* service, a volume that maps a folder containing a compressed, tar archive (extension `.tar.gz`) of the website's WordPress installation folder must be mapped to the `/backup/` directory within the container. Unlike the *db* service, this does **not** trigger a restore when a container first starts, rather it merely makes that archive available to the *wp-cli* helpers that use it - see under [The wp-cli service and its built-in helpers](#the-wp-cli-service-and-its-built-in-helpers) below.

You could map different project directories to the two services as described above, you could provide a backup file to only one of those services or you could provide backup files that don't correspond to the same point in time; however, the most common and sensible use case is a single project directory containing database and WordPress file backups that correspond to the same point in time and restoring from both.

In that scenario, the process to retore a website on the desktop from a backup (database and WordPress file) taken of that same website on a host is as follows:

1. Make sure that the project's containers are stopped and removed:

```sh
docker-compose stop && docker-compose rm
```

2. Remove the volume that holds the project's WordPress files

```sh
docker volume rm varilink_wordpress
```

3. Bring up the *wordpress* service:

```sh
docker-compose up wordpress
```

This will also bring up the *db* and *proxy* services as they are configured as dependencies for the *wordpress* service in this repository's `docker-compose.yml` file. The dependency on the *db* service in particular is configured with a health check that causes the *wordpress* service to wait until the *db* service becomes available before it, itself, comes up. When restoring the database from a backup, this can take a little while.

After you have restored from a backup the website will not be immediately accessible locally. To make it so, a number of the helpers provide by the *wp-cli* service must be run - see [The wp-cli service and its built-in helpers](#the-wp-cli-service-and-its-built-in-helpers) for guidance on running these helpers.

Always correct the site's URL for local use:
```sh
docker-compose run --rm wp-cli _correct-site-url
```

In order to access the admin dashboard locally using convenient, known user credentials:
```sh
docker-compose run --rm wp-cli _create-admin-user
```

If the theme that you're working on locally is not the same theme that is active for the website that the backup was taken from, then you must activate that local theme; for example:
```sh
docker-compose run --rm wp-cli theme activate varilink-site
```

Of course, substitute `varilink-site` with the correct theme name for your usage.

If the theme uses theme images then these must be restored from the filesystem backup:
```sh
docker-compose run --rm wp-cli _restore-media
```

If you want to restore the files for any plugins from the WordPress files backup, then you must do so for each such plugin:
```sh
docker-compose run --rm wp-cli _restore_plugin
```
And select the required plugin when prompted to do so.

### The wp-cli service and its built-in helpers

The wp-cli service provides the [WP-CLI command line interface for WordPress](https://wp-cli.org/) accessing the same WordPress installation folder as does the wordpress service and with access to the database hosted by the db service. This can be confirmed within your project via the command `docker-compose run --rm wp-cli --help`, which of course will display the WP CLI command's help.

The service also wraps the WP CLI with helper shortcuts. These are invoked by passing it commands that are prefixed with an underscore to avoid any clash with a built-in WP CLI command. These helpers can be invoked by passing the helper name to the `wp-cli` service; for example to run the [_correct-site-url](#_correct-site-url) helper:

```bash
docker-compose run --rm wp-cli _correct-site-url
```

You can also provide a single underscore as a command line argument to the `wp-cli`, which will output a menu list of the helpers to select from:

```bash
docker-compose run --rm wp-cli _
```

Here is guidance on each of the defined helpers:

#### _bash

Opens a bash shell within a *wp-cli* service container as the *www-data* user and in the root path of the WordPress installation.

#### _correct-site-url

Any backup will have been taken from one of the environments in use for the website. This means that the links stored in the database associated with that backup will reflect this, they will start with, for example, http://dev.example.com, https://test.example.com or https://www.example.com.

The helper prompts the user to enter the subdomain associated with the backup; for example "dev", "test" or "www". It then performs a search-replace within the database, replacing the original URLs with ones that start with http://*compose-project-name*.

If you intend to use this helper then you need to pass an environment variable DOMAIN through to containers created by the *wp-cli* service. You can do this via you master project `docker-compose.yml` file like this:

```yaml
wp-cli:

  environment:
    - DOMAIN=example.com
```

Note that if you don't run this helper prior to accessing a website that you've restored from backup locally, then this will trigger an immediate redirect to URL associated with the backup. That redirect will be remembered in the browsers cache. So, it's important to run this helper before you try to access the website locally otherwise you will need to clear the remembered redirect.

#### _create-admin-user

This creates a user within the local WordPress site with the name `admin`, the email address `admin@localhost.localdomain`, the role `administrator` and the password `password`. The insecurity of the user's credentials does not matter since the local WordPress site is only accessible on the user's desktop.

This user can then be used to work in the WordPress dashboard locally, with administrator privilege, without having to know any of the logins that were restored from backup.

#### _export-post

This helper allows you to export a post of the post types page or post as a WXR format. It prompts for the name of the post to export, which must correspond to the `post_name` attribute of the post that you want to export.

The post will be exported as a `.xml` file with the name corresponding to `post_name` in to the `wxr` folder within your project. You may wish to ensure that this folder is not Git tracked within your project.

These exported WXR files provide a means to persist posts that you're working on outside of the *db* service's container.

#### _import-post

Just as the [_export-post](#_export-post) helper can be used to export posts to the `wxr` folder within your project, this helper can be used to import WXR files from within that `wxr` folder. It prompts you to select from a list of the `.xml` files there.

Note that a precursor to running this helper is that the `wordpress-importer` plugin is installed and activated. The [_install-importer](#_install-importer) helper can be used to do this.

#### _install-importer

This is a very simple helper that wraps the WP CLI tool's `plugin install` command to specifically install the `wordpress-importer` plugin.

#### _remove-contact-form-recaptcha-integration

I sometimes use the `contact-form-7` plugin with reCAPTCHA integration enabled. Where this is the case, if you restore a website from a backup locally then that integration will be reflected in the `contact-form-7` plugin options. However, this integration is not appropriate when running the website on the local desktop. This plugin disables that integration.

#### _restore-from-backup

This helper restores **all** the WordPress files from the backup into the project's *wordpress* volume. The circumstances in which you might want to use this helper are not routine.

#### _restore-media

When I am developing a custom theme this can include custom media. I upload that custom media to the WordPress media library with the option to organise uploads into year/month folders disabled. This results in the associated media files being stored in the `wp-content/uploads` folder within the WordPress files hierarchy.

If you restore a WordPress site locally then the restored database will contain the record of the media files associated with theme, but the filesystem will not until you run this helper. It restores media files within the `wp-content/uploads` folder in the backup into the *wordpress* volume for the project.

#### _restore-plugin

When you restore a website from backup locally, the local database will then reflect the plugins that were active in the website that the backup was taken from. However the associated plugin files will not be present in your project's *wordpress* volume until you use this plugin to restore them from the backup also.

You may not wish to restore all the plugins because some of them may not be appropriate in a local, desktop environment; for example plugins for integration with Google Analytics and reCAPTCHA services. So this plugin allows you to restore only those plugins you require by prompting you to select an individual plugin from those present in the filesystem backup each time you run it.

You may have to activate a plugin that is restored if WordPress has deactivated it because, prior to having restored the plugin, WordPress couldn't find any files for it.

#### _restore-theme

This helper restores the files for a single selected from the WordPress filesystem backup into the project's *wordpress* volume. It detects the themes that are present in the backup and prompts the user to select which one to us. The circumstances in which you might need to use this helper are not routine.

#### _script

This helper executes a bash script. In this context that's a bash script that executes WP-CLI commands. The *wp-cli* Docker Compose service defined by this repository maps two local directories as volumes; these are the `wordpress/scripts` and `wordpress/varilink-scripts` directories, relative to your project's root directory. You should use `wordpress/varilink-scripts` as the path of a Git submodule in your project which maps to the Varilink [Libraries - WP CLI Scripts](https://github.com/varilink/libraries-wp_cli_scripts) repository.

When this helper is run you need to supply the name of the script to run. This should correspond to a script file that has that same name with a `.sh` suffix added that is present in either or both of your project's `wordpress/scripts` or `wordpress/varilink-scripts` directories. If it is present in both, then it is the script file in `wordpress/scripts` that is used.

So:
```sh
docker-compose run wp-cli --rm _script SCRIPT_NAME
```
Will look for a file *SCRIPT_NAME*.sh, first in `wordpress/scripts` and then, if it doesn't find it there, in `wordpress/varilink-scripts` and will execute it.

The idea here is to make a library of WP-CLI scripts available to run in your project that combines generic scripts from the [Libraries - WP CLI Scripts](https://github.com/varilink/libraries-wp_cli_scripts) repository with project specific scripts defined within your project itself. Those project specific scripts can either override or supplement the generic scripts.
