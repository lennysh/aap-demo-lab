# AAP Configuration as Code Demo Lab

> [!WARNING]
> **🚧 Work in Progress 🚧**
>
> This repository is under active development. Features may be incomplete, subject to breaking changes, or not fully tested. Please use with caution.

Welcome! 👋 This repository provides a powerful, version-aware framework for managing your Ansible Automation Platform (AAP) environment using a Configuration as Code (CaC) approach. It's designed to handle multiple AAP versions seamlessly, ensuring that the correct Ansible Collections and Execution Environments are used automatically.

This framework allows you to **extract ("read")** your existing AAP configuration into local YAML files and **apply ("update")** version-controlled configurations back to your AAP instance.

## Key Features 🚀

* **Multi-Version Support:** Manages configurations for AAP 2.4, 2.5, and 2.6, automatically selecting the correct tools for each.
* **Ansible-Navigator Integration:** Uses `ansible-navigator` with version-specific **Execution Environments (EEs)** to guarantee a consistent and reliable runtime with the correct dependencies.
* **Structured Configuration:** Organizes all AAP settings in a logical directory structure based on **Organizations** and **Environments** (`orgs_vars/<my_org>/env/<my_env>`).
* **Simplified Workflow:** Provides simple wrapper scripts (`aapread.sh` and `aapupdate.sh`) for exporting and importing configurations without needing to write complex `ansible-navigator` commands.

---

## Prerequisites

Before you begin, make sure you have the following tools installed on your local machine:

* **Git:** To clone the repository.
* **[ansible-navigator](https://ansible-navigator.readthedocs.io/en/latest/installation/)**: The primary tool used to run the Ansible playbooks.
* **[yq](https://github.com/mikefarah/yq#install)**: A command-line YAML processor used by the scripts for validation and data extraction.
* **A Container Engine:** `ansible-navigator` requires a container engine like **Podman** (recommended) or **Docker** to run the Execution Environments.
* **Network Access:** Your machine must be able to pull the required EE images from `quay.io` and connect to your AAP instance's API.

---

## ⚙️ Setup and Configuration

Follow these steps to get the repository configured for your environment.

### 1. Clone the Repository

First, clone this repository to your local machine:
```shell
git clone <your-repo-url>
cd aap-demo-lab
```

### 2. Configure Ansible

Copy the example Ansible configuration file. This file is pre-configured with sensible defaults, including a setting to use a vault password file.
```shell
cp ansible.cfg.example ansible.cfg
```
The provided `ansible.cfg` example is set up to look for a vault password in a file named `vault_pass.txt` in the root of the repository.

### 3. Provide AAP Credentials

You need to provide credentials for connecting to your AAP instance. You can do this in one of two ways:

#### Option A: Ansible Vault (Recommended ✨)

This is the most secure method. Credentials are encrypted and stored within the repository.

1.  **Create a Vault Password File**: Create a file named `vault_pass.txt` in the root of the project. Add your desired vault password to this file and save it.
    ```shell
    # Note: Ensure this file is included in your .gitignore to avoid committing it!
    echo "your-secret-vault-password" > vault_pass.txt
    ```

2.  **Create an Encrypted Vault File**: For the environment you want to manage (e.g., organization `DEMOLab` and environment `AAP26`), create an encrypted `vault.yml` file.

    ```shell
    # Create the directory if it doesn't exist
    mkdir -p orgs_vars/DEMOLab/env/AAP26

    # Create and encrypt the vault file
    ansible-vault encrypt orgs_vars/DEMOLab/env/AAP26/vault.yml
    ```
    When prompted, enter the same password you placed in `vault_pass.txt`. Then, add your AAP connection details to the file:
    ```yaml
    # orgs_vars/DEMOLab/env/AAP26/vault.yml
    ---
    vault_aap_hostname: "aap-controller.example.com"
    vault_aap_username: "admin"
    vault_aap_password: "your-aap-password"
    vault_aap_validate_certs: false
    ```

#### Option B: Environment Variables (Quick Start 💨)

For testing, you can set environment variables. The playbooks will use these if vault variables are not found.

```shell
export AAP_HOST="aap-controller.example.com"
export AAP_USERNAME="admin"
export AAP_PASSWORD="your-aap-password"
export AAP_VERIFY_SSL=false
```

---

## 📁 Directory Structure

The repository is organized to keep configurations separate and easy to manage:

* `orgs_vars/`: This is where all your AAP configuration data lives.
    * `<organization_name>/`: A folder for each AAP organization you manage.
        * `env/`: Contains environment-specific configurations.
            * `common/`: Holds settings shared across all environments for that organization.
            * `<environment_name>/`: Contains `vars.yml` (for defining the AAP version) and `vault.yml` (for secrets) specific to one AAP instance.
* `script_vars/`: Contains configuration for the wrapper scripts themselves.
    * `<version>/vars.yml`: Defines the **Execution Environment image** and the **valid tags** for a specific AAP version.
* `tasks/`: Contains the version-specific Ansible tasks. The `casc_aap_version` variable in your environment's `vars.yml` determines which sub-directory of tasks is used.

---

## 🚀 Usage

The primary way to interact with your AAP instance is through the `aapread.sh` and `aapupdate.sh` scripts.

### Downloading (Reading) from AAP

The `aapread.sh` script connects to an AAP instance and downloads its current configuration into a timestamped local folder. This is great for making a backup or for bootstrapping your CaC repository.

**Command:**
```shell
./aapread.sh <organization> <environment> [-t <tags>]
```

**Example:**
To download all settings for the `AAP26` environment defined under the `DEMOLab` organization:
```shell
./aapread.sh DEMOLab AAP26 -a
```
This will create a new directory like `temp/aapread_AAP26_20251009_112316/` containing the exported YAML files.

### Uploading (Updating) to AAP

The `aapupdate.sh` script applies the configuration from your local `orgs_vars` directory to the target AAP instance. You can apply all settings or be selective with tags.

**Command:**
```shell
./aapupdate.sh <organization> <environment> [-a|--all] [-t <tags>]
```

**Example:**
To update only the **Projects** and **Job Templates** for the `AAP26` environment:
```shell
./aapupdate.sh DEMOLab AAP26 -t "projects,job_templates"
```

**Available Tags:**
The available tags depend on the AAP version specified in your environment's `vars.yml`. The script will automatically validate the tags you provide. For AAP 2.6, the available tags for an update include:
* applications
* credential_input_sources
* credential_types
* credentials
* execution_environments
* groups
* hosts
* instance_groups
* inventories
* inventory_sources
* job_templates
* labels
* notifications
* organizations
* projects
* roles
* schedules
* settings
* teams
* users
* workflow_job_templates

---

## 🧙 How it Works: The "Magic" Explained

The multi-version support is handled dynamically based on your configuration:

1.  You run a script, for example: `./aapupdate.sh DEMOLab AAP26 -t projects`.
2.  The script reads the `casc_aap_version` variable from `orgs_vars/DEMOLab/env/AAP26/vars.yml`. Let's say it finds `2.6`.
3.  Using the version `2.6`, the script looks up the correct Execution Environment image (`quay.io/lshirley/ansible-automation-platform-26/ee-casc-rhel9`) and validates the `projects` tag from the file `script_vars/2.6/vars.yml`.
4.  The script then executes the main `aapupdate.yml` playbook.
5.  This playbook dynamically includes the tasks from the `tasks/2.6/` directory, which contain the Ansible modules and roles compatible with AAP 2.6 (e.g., `infra.aap_configuration.dispatch`).

This process ensures that no matter which environment you target, the correct set of tools is used every time.

---

## 📜 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.