# Minecraft Server Toolkit

This is a basic [Ansible](http://docs.ansible.com/) playbook to create an on-demand Minecraft server on DigitalOcean that uses [Block Storage](https://www.digitalocean.com/products/storage/) to persist game data.  This allows you to shut down the server when not in use without affecting your world or in-game inventory data.

## Dependencies

* Python 3.11+

Installation of Python via [pyenv](https://github.com/pyenv/pyenv) is recommended -- it will automatically use the version specified in `.python-version` once installed.

## Setup

Before you can provision your new server, you'll need to ensure that the necessary dependencies and credentials are installed:

### Dependencies

Setup automation is provided by make, simply run the `setup` target:

```
$ make setup
```

This will ensure that your local configuration files are in place and that all necessary Python and Ansible dependencies are installed.

### Credentials

Once dependencies are installed, you will need to edit the `vars/credentials.yml` file and provide your [DigitalOcean API key](https://cloud.digitalocean.com/settings/api/tokens):

```yaml
---
credentials:
  digital_ocean:
    api_key: d34db33f
```

#### DigitalOcean API token scopes

The `community.digitalocean` modules call endpoints beyond the obvious ones — for example, `digital_ocean_droplet` queries `/v2/firewalls` even when the droplet is not associated with any firewall, so the token needs `firewall:read` or droplet creation will fail with "Failed to get firewalls: You are not authorized to perform this operation".

Minimum required scopes for `make provision` and `make destroy`:

| Resource | Scopes |
|----------|--------|
| `droplet` | `create`, `read`, `delete` |
| `ssh_key` | `create`, `read` |
| `block_storage` | `create`, `read`, `update` |
| `firewall` | `read` |
| `image` | `read` |

If you hit a "not authorized" error on an unexpected endpoint, either add the corresponding scope or generate a "Full Access" token for throwaway testing. Always set a finite expiry (1 day / 1 week) rather than "No expiry".

This playbook can also create a DNS entry using the [DNSimple](https://dnsimple.com) service.  If you are a a DNSimple customer, you can configure your credentials in `vars/credentials.yml` as well:

```yaml
---
credentials:
  digital_ocean:
    api_key: d34db33f
  dnsimple:
    account_email: user@host.com
    account_api_token: t0k3n
```

## Configuration

### Server Creation

Sensible defaults have been chosen for the server creation options, but you can always override those as needed:

```yaml
# vars/server.yml
server:
  ssh_key_name: "Ansible / Minecraft"
  image: ubuntu-22-04-x64
  region: nyc3
  size: s-2vcpu-2gb
  name: minecraft
```

See the [DigitalOcean size slugs reference](https://slugs.do-api.dev/) for other options. Legacy slugs like `2gb`, `4gb` were retired — use `s-<vcpu>-<ram>` (basic), `g-<vcpu>-<ram>` (general purpose), or other current formats.

### Minecraft Server Configuration

The Minecraft server is configured by a local Ansible role at `roles/minecraft/`. The variables you typically set in `vars/server.yml` are:

```yaml
minecraft_home: /srv/minecraft
minecraft_version: 1.21.4
minecraft_accept_eula: true  # https://www.minecraft.net/en-us/eula
```

`minecraft_accept_eula` must be `true` — the role asserts it before doing any other work. See `roles/minecraft/defaults/main.yml` for additional knobs (Java package, JVM heap size, user/group names).

### Configuring DNS Records (Optional)

If you have credentials set for DNSimple, you can configure the domain and hostname of the record that will be created -- this will point to your newly created server:

```yaml
# vars/server.yml
dns:
  domain: my-domain.com
  hostname: minecraft
  ttl: 300
``` 

## Creating the Server

Ensure that all dependencies are installed, and then run the `provision` target to create your new server:

```
$ make provision
```

When successful, your new server will be ready to use -- you can either try using the created hostname if you are using DNSimple, or the IP captured in the `inventory` file to connect.

## Destroying the Server

It's important to shut down the Minecraft server process and unmount the Block Storage volume before deleting the server.  To do this correctly, you just need to run the `destroy` target:

```
$ make destroy
```

## Provisioning via GitHub Actions

Three workflows under `.github/workflows/` let anyone with repo write access spin up and tear down a session server without cloning the repo locally.

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `provision.yml` | Manual (`workflow_dispatch`) | Create droplet, attach `minecraft-data` volume, install server. Inputs: region, size, `duration_hours` (used for auto-destroy). |
| `destroy.yml` | Manual (`workflow_dispatch`) | Stop service, unmount volume, destroy droplet, remove DNS record. |
| `auto-destroy.yml` | Cron (`*/15 * * * *`) | Inspect live droplet's `expires-<unix>` tag and run the destroy flow once the TTL has passed. |

All three share concurrency group `minecraft-server` so they cannot race each other. `provision.yml` and `destroy.yml` are gated on the `minecraft-server` GitHub Environment so an explicit reviewer click is required — `auto-destroy.yml` is not gated since it runs unattended.

### Required repository secrets

| Secret | Purpose |
|--------|---------|
| `DO_API_KEY` | DigitalOcean API token (same scopes as for local `make provision`). |
| `DNSIMPLE_ACCOUNT_EMAIL` | DNSimple account email. |
| `DNSIMPLE_ACCOUNT_API_TOKEN` | DNSimple API token. |
| `DNSIMPLE_DOMAIN` | Apex domain that will host the `minecraft.<domain>` A record. |
| `ANSIBLE_SSH_PRIVATE_KEY` | Persistent SSH private key the workflows use to manage the droplet. Generate once with `ssh-keygen -t ed25519 -N '' -f keys/ansible -C minecraft-ci` locally and copy the file contents into the secret. |
| `ANSIBLE_SSH_PUBLIC_KEY` | Matching public key. |

### One-time GitHub setup

1. **Repository → Settings → Environments**: create `minecraft-server`, add yourself (and any other write-access users) under **Required reviewers**.
2. **Repository → Settings → Secrets and variables → Actions**: add the secrets above.
3. (Optional) Restrict `workflow_dispatch` to specific actors via branch protection / environment policies if the repo is public.

### Running

- **Provision**: Actions → *Provision Minecraft server* → *Run workflow* → choose region/size/duration → approve in the environment prompt → workflow summary contains the FQDN, IP, and expiry timestamp.
- **Destroy early**: Actions → *Destroy Minecraft server* → *Run workflow* → approve.
- **Auto-destroy**: nothing to do; cron polls every 15 min and tears down once `now >= expires-<unix>`.
