# ------------------------------------------------------------------------------
# wp-cli/docker-entrypoint.sh
# ------------------------------------------------------------------------------

# Wrapper script to WP-CLI that provides several shortcut "helper scripts" as
# well as the native fuctionality of WP-CLI itself.

# ------

function helper_menu {

  # Show a menu of the available helpers for the user to select one.

  echo 'Helpers available'
  PS3='Helper? '
  select helper in                                                             \
    _bash                                                                      \
    _correct-site-url                                                          \
    _create-admin-user                                                         \
    _export-post                                                               \
    _import-post                                                               \
    _install-importer                                                          \
    _make-backup                                                               \
    _remove-contact-form-recaptcha-integration                                 \
    _restore-from-backup                                                       \
    _restore-media                                                             \
    _restore-plugin                                                            \
    _restore-theme                                                             \
    _exit
  do
    if [[ -n $helper ]]
      then
        command=$helper
        break
      else
        echo 'Invalid selection, enter the number of a helper in the list'
    fi
  done

}

case $1 in

  _bash |                                                                      \
  _correct-site-url |                                                          \
  _create-admin-user |                                                         \
  _export-post |                                                               \
  _import-post |                                                               \
  _install-importer |                                                          \
  _make-backup |                                                               \
  _remove-contact-form-recaptcha-integration |                                 \
  _restore-from-backup |                                                       \
  _restore-media |                                                             \
  _restore-plugin |                                                            \
  _restore-theme |                                                             \
  _script |                                                                    \
  _exit)

    command=$1

  ;;

  _)

    helper_menu

  ;;

  _*)

    # The user has probably tried to specify a helper via the underscore prefix
    # but they've not then provided a helper name that we recognise.

    echo 'That helper name is not recognised, select from this menu'
    helper_menu

  ;;

  *)

    command=$1

  ;;

esac

case $command in

  _bash)

    gosu www-data bash $2

  ;;

  _correct-site-url)

    read -p 'Enter the backup subdomain ("dev", "test" or "www"): ' subdomain
    echo $subdomain
    gosu www-data wp search-replace --report-changed-only                      \
      https://$subdomain.$DOMAIN http://$COMPOSE_PROJECT_NAME

  ;;

  _create-admin-user)

    # Create an admin user for use within the container

    # It doesn't matter that the credentials are not secure since we're only
    # going to use this user on the developer desktop.
    gosu www-data wp                                                           \
      user create admin admin@localhost.localdomain                            \
      --role=administrator --user_pass=password

  ;;

  _export-post)

    cd /wxr
    read -p 'Post name: ' post_name

    # NOTE: The post list requires that the post is published
    gosu host_user wp export                                                   \
      --path=/var/www/html/                                                    \
      --post__in="$(                                                           \
          gosu host_user wp post list                                          \
            --path=/var/www/html/                                              \
            --name=$post_name                                                  \
            --format=ids                                                       \
            --post_type=page,post                                              \
        )"                                                                     \
      --filename_format=${post_name}.xml

  ;;

  _import-post)

    echo 'Post files available'
    PS3='Post file? '
    select post_file in `cd /wxr && ls *.xml` exit
    do

      if [[ "$post_file" != 'exit' ]]
      then

        gosu www-data wp import                                                \
          --path=/var/www/html/                                                \
          /wxr/${post_file}                                                    \
          --authors=skip

      fi

      break

    done

  ;;

  _install-importer)

    gosu www-data wp                                                           \
      --allow-root                                                             \
      plugin install wordpress-importer --activate

  ;;

  _make-backup)

    gosu host_user rm /backup/*.gz
    gosu host_user wp db export /backup/database.sql
    gosu host_user gzip /backup/database.sql
    tar -czvf /tmp/html.tar.gz /var/www/html
    gosu host_user cp /tmp/html.tar.gz /backup/.

  ;;

  _remove-contact-form-recaptcha-integration)

    # Remove Contact Form 7 integration with reCAPTCHA

    gosu www-data wp option patch delete wpcf7 recaptcha

  ;;

  _restore-from-backup)

    echo 'Restoring the WordPress installation from the backup to the container'

    # Find the archive file of website's home folder
    archive=$(find /backup -name "*.tar.gz")
    echo "Archive file found at $archive"

    wp_settings=$(tar --list --file=$archive --wildcards "*/wp-settings.php")
    # Extract all the forward slashes from the full path of the wp_config file
    slashes="${wp_settings//[^\/]}"
    # Count the components to strip from file names on extraction
    components="${#slashes}"

    echo $components

    # If I have used a bacula restore to create the archive, then it will
    # contain the wp-config.php file. If I have used `scp -rp` instead, then it
    # won't because of file permissions on the live server. Look to see if this
    # archive contains the wp-config.php file. Using `grep` rather than a tar
    # wildcard pattern avoids a bash failure status that halts execution.
    if [ $(tar --list --file=$archive | grep -F 'wp-config.php') ]
      then

        wp_config=$(tar --list --file=$archive --wildcards "*/wp-config.php")
        echo "wp-config.php found at $wp_config"
        # Extract from the archive to the WordPress home in the container
        tar                                                                    \
          --extract                                                            \
          --file=$archive                                                      \
          --directory=/var/www/html                                            \
          --strip-components=$components                                       \
          --exclude=$wp_config

      else

        echo 'No wp-config.php file found in the archive'
        tar                                                                    \
          --extract                                                            \
          --file=$archive                                                      \
          --directory=/var/www/html                                            \
          --strip-components=$components

    fi

    echo 'Extract from the archive completed'

  ;;

  _restore-media)

    # Find the archive file of website's home folder
    archive=$(find /backup -name "*.tar.gz")
    echo "Archive file found at $archive"

    if [[ ! -e /var/www/html/wp-content/uploads ]]
      then
        mkdir -p /var/www/html/wp-content/uploads
    fi

    gosu www-data tar                                                          \
      --extract                                                                \
      --file=$archive                                                          \
      --directory=/var/www/html/wp-content/uploads                             \
      --transform="s~.*wp-content/uploads/~~"                                  \
      --wildcards                                                              \
      "**wp-content/uploads/**"

  ;;

  _restore-plugin)

    # This helper restores the files associated with a single plugin that is
    # selected by the user from a WordPress filesystem backup to the project's
    # wordpress volume.

    # Find the archive file of website's home folder
    archive=$(find /backup -name "*.tar.gz")
    echo "Archive file found at $archive"

    # List every file in the archive in the wp-contents/plugins/ directory.
    for path in                                                                \
      $(tar --list --file=$archive --wildcards "**wp-content/plugins/")
    do
      regex='wp-content/plugins/([a-z0-9-]+)/$'
      if [[ $path =~ $regex ]]
        # The file is the top-level directory for a plugin.
        then
          if [[ -z "$plugins" ]]
            then
              # Start the variable plugins that contains a list of plugins.
              plugins=${BASH_REMATCH[1]}
            else
              # Append the latest plugin found to the list of plugins.
              plugins="$plugins ${BASH_REMATCH[1]}"
          fi
      fi
    done

    # Prompt the user for the plugin that they wish to restore.
    echo 'Plugins available'
    PS3='Plugin to restore? '
    select plugin in $plugins
    do
      if [[ -n $plugin ]]
        then
          set -- "$plugin"
          break
        else
          echo 'Invalid selection, enter the number of a plugin in the list'
      fi
    done

    # Restore the selected plugin.
    gosu www-data tar                                                          \
      --extract                                                                \
      --file=$archive                                                          \
      --directory=/var/www/html/wp-content/plugins                             \
      --transform="s~.*wp-content/plugins/~~"                                  \
      --wildcards                                                              \
      "**wp-content/plugins/$plugin/**"

  ;;

  _restore-theme)

    # This helper restores the files associated with a single theme that is
    # selected by the user from a WordPress filesystem backup to the project's
    # wordpress volume.

    # Find the archive file of website's home folder
    archive=$(find /backup -name "*.tar.gz")
    echo "Archive file found at $archive"

    # List every file in the archive in the wp-contents/themes/ directory.
    for path in                                                                \
      $(tar --list --file=$archive --wildcards "**wp-content/themes/")
    do
      regex='wp-content/themes/([a-z0-9-]+)/$'
      if [[ $path =~ $regex ]]
        # The file is the top-level directory for a theme.
        then
          if [[ -z "$themes" ]]
            then
              # Start the variable plugins that contains a list of themes.
              themes=${BASH_REMATCH[1]}
            else
              # Append the latest theme found to the list of themes.
              themes="$themes ${BASH_REMATCH[1]}"
          fi
      fi
    done

    # Prompt the user for the theme that they wish to restore.
    echo 'Themes available'
    PS3='Theme to restore? '
    select theme in $themes
    do
      if [[ -n $theme ]]
        then
          set -- "$theme"
          break
        else
          echo 'Invalid selection, enter the number of a theme in the list'
      fi
    done

    # Restore the selected theme.
    gosu www-data tar                                                          \
      --extract                                                                \
      --file=$archive                                                          \
      --directory=/var/www/html/wp-content/themes                              \
      --transform="s~.*wp-content/themes/$theme/~$theme/~"                     \
      --wildcards                                                              \
      "**wp-content/themes/$theme/"

  ;;

  _script)

    if [ -f "/scripts/$2.sh" ]; then
      gosu www-data bash "/scripts/$2.sh"
    elif [ -f "/varilink-scripts/$2.sh" ]; then
      gosu www-data bash "/varilink-scripts/$2.sh"
    else
      echo 'The script does NOT exist'
    fi

  ;;

  _exit)

    # The user has most probably entered the option number for "_exit" in the
    # helper selection menu. Just do nothing and drop out of the bottom of this
    # case statement.

  ;;

  *)

    # Just pass the parameters passed to the wp-cli Docker Compose service
    # directly through to the WP-CLI command. This gives direct access to the
    # native WP-CLI functionality, bypassing the helpers above.

    gosu www-data wp "$@"

  ;;

esac
