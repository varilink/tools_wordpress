Items to add to this read me:

- The pma service
- The new _make-backup helper
- The change to the _script helper whereby you can specify the script to run up front
- The distinction between scripts invoked via the _script helper and scripts that are part of the wrapper to other helpers
- If you restore from database using `--env-file backup.env` and you subsequently stop the *db* container then when you restart it you must use `--env-file backup.env` even if you don't won't to restore again because otherwise the container will be recreated.




# Tools - WordPress

David Williamson @ Varilink Computing Ltd

------

This repository defines Docker Compose services that run any WordPress based website on the desktop along with a phpMyAdmin service, for convenient inspection of the WordPress database, and integration with the [WP-CLI](https://wp-cli.org/) command-line interface for WordPress, which this repository also supplements with various helper functions.

## Contents

| File/Directory       | Description                                            |
| -------------------- | ------------------------------------------------------ |
| `docker-compose.yml` | Docker Compose project configuration.                  |
| `wp-cli/`            | Artefacts used by the `wp-cli` Docker Compose service. |

## Installation

1. Add this repository as a submodule of a project that uses it. This must be at the path `tools/wordpress/` relative to the root folder of that master project.

2. Set the following Docker Compose environment variables in the project:
   - COMPOSE_FILE (see below)
   - COMPOSE_PROJECT_NAME
   - DOMAIN
   - MARIADB_TAG
   - PHP_TAG
   - PROXY_PORT
   - WORDPRESS_TAG

3. Add any master Docker Compose file to your project, which you may use in order to extend the services defined in this repository; for example in order to pass through project specific environment variables, but which must be present in any case.

4. Apply all the required Docker Compose files for your project in the right order using the COMPOSE_FILE environment variable for convenience. Note that you must include the master Docker Compose file in the project's root folder **first** in the `COMPOSE_FILE` variable, since this then sets the root folder for any relative paths in all the subsequent Docker Compose files - see [this issue on GitHub](https://github.com/docker/compose/issues/3874), which identifies the workaround of using an empty Docker Compose file in the project's root folder where there isn't already one in there that can be referenced first.

5. To make the project's WordPress website available in the web browser on the desktop, also add the Varilink Computing Ltd [tools_proxy](https://github.com/varilink/tools_proxy) repository as a submodule of the master project. Usage help for that tool can be found in [tools_proxy/README.md](https://github.com/varilink/tools_proxy/blob/main/README.md).

Examples of this tool being used in projects can be found in the Docker repositories associated with my WordPress projects here:
- [FoBV - Docker](https://github.com/varilink/fobv_docker)
- [New Opera Company - Docker](https://github.com/varilink/newopera_docker)
- [Website - Docker](https://github.com/varilink/website_docker)

## Usage

### Starting a project from scratch

When starting work on a project for the first time, with no existing project containers or volumes in place, simply bring the project's `wordpress` service:

```sh
docker-compose up wordpress
```

Note that whenever you bring up the *wordpress* service, the *db* and *proxy* services are automatically started as dependencies. The dependency on the *db* service is configured with a health check that the *db* service is available for connections before the *wordpress* service is brought up. In some circumstances this may take a little time but if wait a while it should happen eventually.

When the *wordpress* service has come up, you will then be able to run the WordPress installation script for your development website at `http://${COMPOSE_PROJECT_NAME}` in a web browser on your desktop, provided you have the right proxy port mapping in place - see [tools_proxy/README.md](https://github.com/varilink/tools_proxy/blob/main/README.md).

In this mode it's probable that you won't need to provide any project overrides for the Docker Compose services provided by this tool. As noted above however, the Docker Compose file listed first in the `COMPOSE_FILE` must be a project file in the project's root folder. As highlighted in the GitHub issue referenced above, this can be achieved using a Docker Compose file that is empty; however you must include at least one service identifier in this Docker Compose file even if you don't need to provide any project overrides, otherwise Docker will assign is version 1 of the Docker Compose file specification.

For example:

```yaml
services:

  wordpress:

```

The `docker-compose.yml` files that come with Docker Compose based Varilink Computing Ltd tools, including this one, do **not** specify a Docker Compose file version number. If you similarly do not specify a version number in any of your project specific Docker Compose files, then Docker seems to infer the version from the syntax of the service definitions.

The WordPress installation folder is stored in a volume named *wordpress*, which will be created with the name `${COMPOSE_PROJECT_NAME}_wordpress`. This is because it is shared by both the wordpress and wp-cli Docker Compose services. Be alert that this means it must be explicitly removed if that's required. It can't be cleared by simply removing the containers that use it.

### Testing a WordPress Project's Theme and Plugins

*This section will describe the typical development use of this tool, in which a project's theme and plugins are mapped as Docker volumes into the running WordPress container. It will also reference the template Git Docker Compose repository for WordPress projects, which has yet to be created.*

### Restoring a project from backup

You can restore a WordPress website from backup to work on updates to it locally. There are two aspects to this, the database and the WordPress files, which my development lifecycle assumes will be stored as `database.sql.gz` and `html.tar.gz` respectively. The files that you intend to use to restore from for both aspects must be contained with the directory `backup/`  within your WordPress project's Docker Compose repository.

To facilitate this, I recommend having a separate Docker Compose setup within your project. I use two pairs of Docker Compose configuration files, each pair consisting of a Docker Compose file environment file and a Docker Compose services file.

For example:

- `.env` and `docker-compose.yml` for normal running

- `backup.env` and `backup.yml` for when I wish to restore from a backup

Typically, the differences between these setups is as follows:

- The `.env` and `backup.env` files may specify different values for `MARIADB_TAG`, `PHP_TAG` and `WORDPRESS_TAG` if there are differences in the versions of MariaDB, PHP and WordPress used by your website under development and the backup you're restoring from.

- The `backup.env` file will **not** concatenate Docker Compose files in the value of the `COMPOSE_FILE` environment variable other than those for the Varilink [Tools - Proxy](git@github.com:varilink/tools_proxy.git) and [Tools - WordPress](git@github.com:varilink/tools_wordpress.git) since other tools that are part of the development lifecycle are not relevant if you're simply restoring from backup.

- The `backup.yml` file defines `./backup/database.sql.gz` as a volume mapped to `/docker-entrypoint-initdb.d/database.sql.gz` within the *db* service.

- In contrast to the `docker-compose.yml` file, the `backup.yml` file will **not** define volumes for the project's theme or plugins, since again this is not relevant if you're simply restoring from backup.

The process for restoring from a backup is as follows:

1. Clear down the project's Docker Compose environment:

```sh
docker-compose stop
docker-compose rm
docker volume rm PROJECT_wordpress
```

where `PROJECT` is the value set by the `COMPOSE_PROJECT_NAME` environment variable.

2. Bring up *db* service, using the Docker Compose configuration specific to restoring from backup:

```sh
docker-compose --env-file backup.env up db
```

If you read the section *Initializing the database contents* in [Docker Hub's mariadb image page](https://hub.docker.com/_/mariadb), then you will see that this will result in the database being populated from `database.sql.gz`.

3. While the *db* service is still up, run the [_restore-from-backup](#_restore-from-backup) helper that is built into the *wp-cli* service:

```sh
docker-compose --env-file backup.env run --rm wp-cli _restore_from_backup
```

4. Bring up the *wordpress* service using the same environment for restoring from backup:

```sh
docker-compose --env-file backup.env up wordpress
```

The next step is optional depending on the source of your backup. Backups come from one of two sources:

  - A host (not a Docker container) that an instance of the project's WordPress site is deployed to. These backups are created by the using the Varilink tools implemented by [Tools - WordPress Restore](https://github.com/varilink/tools_wordpress-restore) and [Tools - WordPress Make Backup](https://github.com/varilink/tools_wordpress-make-backup) in combination.

  - A backup made from an instance of the WordPress site running within a container on the desktop using this tool. The *wp-cli* service's [_make-backup](#_make-backup) helper can be used to create these backups. This can be useful to conveniently persist work done of a version of the WordPress site on the desktop outside of the Docker containers and volumes and in a form that can be readily restored from.

If the source is the first of these then before you can access the restored WordPress site on the desktop you must change the site's URL to that used on the desktop. You can do this using the *wp-cli* service's [_correct-site-url](#_correct-site-url) helper:

```sh
docker-compose run --rm wp-cli _correct-site-url
```

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

#### _make-backup

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
