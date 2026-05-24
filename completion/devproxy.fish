# Fish completion for devproxy
# Install: copy to ~/.config/fish/completions/devproxy.fish
# or run: devproxy completion fish > ~/.config/fish/completions/devproxy.fish

# Disable file completion by default
complete -c devproxy -f

# Top-level commands
complete -c devproxy -n '__fish_use_subcommand' -a 'create'     -d 'Create a new domain with proxy configuration'
complete -c devproxy -n '__fish_use_subcommand' -a 'remove'     -d 'Remove a domain and its configuration'
complete -c devproxy -n '__fish_use_subcommand' -a 'update'     -d 'Check for updates and install if available'
complete -c devproxy -n '__fish_use_subcommand' -a 'cert'       -d 'Manage SSL certificates'
complete -c devproxy -n '__fish_use_subcommand' -a 'hosts'      -d 'Manage /etc/hosts entries'
complete -c devproxy -n '__fish_use_subcommand' -a 'nginx'      -d 'Manage nginx site configurations'
complete -c devproxy -n '__fish_use_subcommand' -a 'mode'       -d 'Show or change proxy mode'
complete -c devproxy -n '__fish_use_subcommand' -a 'config'     -d 'Show current configuration'
complete -c devproxy -n '__fish_use_subcommand' -a 'completion' -d 'Output shell completion script'
complete -c devproxy -n '__fish_use_subcommand' -a 'help'       -d 'Show help message'

# Global flags
complete -c devproxy -n '__fish_use_subcommand' -s v -l version -d 'Show version and exit'
complete -c devproxy -l help -d 'Show help message'

# cert subcommands
complete -c devproxy -n '__fish_seen_subcommand_from cert' -a 'generate' -d 'Generate SSL certificate'
complete -c devproxy -n '__fish_seen_subcommand_from cert' -a 'remove'   -d 'Remove SSL certificate'
complete -c devproxy -n '__fish_seen_subcommand_from cert' -a 'list'     -d 'List all certificates'

# hosts subcommands
complete -c devproxy -n '__fish_seen_subcommand_from hosts' -a 'add'    -d 'Add entry to /etc/hosts'
complete -c devproxy -n '__fish_seen_subcommand_from hosts' -a 'remove' -d 'Remove entry from /etc/hosts'
complete -c devproxy -n '__fish_seen_subcommand_from hosts' -a 'list'   -d 'List /etc/hosts entries'

# nginx subcommands
complete -c devproxy -n '__fish_seen_subcommand_from nginx' -a 'create-site'   -d 'Create proxy site configuration'
complete -c devproxy -n '__fish_seen_subcommand_from nginx' -a 'create-static' -d 'Create static site configuration'
complete -c devproxy -n '__fish_seen_subcommand_from nginx' -a 'remove-site'   -d 'Remove site configuration'
complete -c devproxy -n '__fish_seen_subcommand_from nginx' -a 'list'          -d 'List all site configurations'
complete -c devproxy -n '__fish_seen_subcommand_from nginx' -a 'test'          -d 'Test nginx configuration'
complete -c devproxy -n '__fish_seen_subcommand_from nginx' -a 'reload'        -d 'Reload nginx'

# completion subcommands
complete -c devproxy -n '__fish_seen_subcommand_from completion' -a 'bash' -d 'Bash completion script'
complete -c devproxy -n '__fish_seen_subcommand_from completion' -a 'zsh'  -d 'Zsh completion script'
complete -c devproxy -n '__fish_seen_subcommand_from completion' -a 'fish' -d 'Fish completion script'

# Shared options for create / nginx create-site / nginx create-static
complete -c devproxy -n '__fish_seen_subcommand_from create' -s h -l host        -d 'Domain name' -r
complete -c devproxy -n '__fish_seen_subcommand_from create' -s p -l port        -d 'Port number' -r
complete -c devproxy -n '__fish_seen_subcommand_from create' -s i -l ip          -d 'IP address' -r
complete -c devproxy -n '__fish_seen_subcommand_from create' -s s -l subdomain   -d 'Treat as subdomain'
complete -c devproxy -n '__fish_seen_subcommand_from create' -s m -l main-domain -d 'Main domain for subdomain' -r
complete -c devproxy -n '__fish_seen_subcommand_from create' -l no-ssl           -d 'Disable SSL'
complete -c devproxy -n '__fish_seen_subcommand_from create' -l ssl              -d 'Enable SSL (default)'
complete -c devproxy -n '__fish_seen_subcommand_from create' -l template         -d 'Custom nginx template' -r -F
complete -c devproxy -n '__fish_seen_subcommand_from create' -l mode             -d 'Proxy mode' -r -a 'docker local auto'
complete -c devproxy -n '__fish_seen_subcommand_from create' -l static           -d 'Serve static files'
complete -c devproxy -n '__fish_seen_subcommand_from create' -l root             -d 'Document root for static sites' -r -F

# remove options
complete -c devproxy -n '__fish_seen_subcommand_from remove' -s h -l host -d 'Domain name to remove' -r

# mode options
complete -c devproxy -n '__fish_seen_subcommand_from mode' -l mode -d 'Proxy mode' -r -a 'docker local auto'