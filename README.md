# Minecraft Server Toolkit

This is a basic [Ansible](http://docs.ansible.com/) playbook to create an on-demand Minecraft server on DigitalOcean that uses [Block Storage](https://www.digitalocean.com/products/storage/) to persist game data.  This allows you to shut down the server when not in use without affecting your world or in-game inventory data.

## Dependencies

* Python 2.7.x

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

This playbook can also create a DNS entry using the [DNSimple](https://dnsimple.com) service.  If you are a a DNSimple customer, you can configure your credentials in `vars/credentials.yml` as well:

```yaml
---
credentials:
  digital_ocean:
    api_key: d34db33f
  dnsimple:
    email: user@host.com
    api_key: t0k3n
```

## Configuration

### Server Creation

Sensible defaults have been chosen for the server creation options, but you can always override those as needed:

```yaml
# vars/server.yml
server:
  ssh_key_name: "Ansible / Minecraft"
  image_id: ubuntu-16-04-x64
  region_id: nyc3
  size_id: 4gb
  name: minecraft
```

### Minecraft Server Configuration

You can also tweak your Minecraft server settings based on the variables provided by the included Ansible role:

See the documentation for the [`devops-coop.minecraft` Ansible role](https://github.com/devops-coop/ansible-minecraft#role-variables) for all available options.

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
