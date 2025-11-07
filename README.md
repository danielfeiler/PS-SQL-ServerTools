# PS-SQL-ServerTools

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)

A collection of useful PowerShell scripts for working with Microsoft SQL Server. These scripts help automate common SQL Server administration tasks, particularly for SQL Server Always-On Availability Groups and user management.

## Overview

This repository contains PowerShell scripts designed to simplify SQL Server administrative tasks. Whether you're managing Always-On Availability Groups, handling user synchronization, or performing routine maintenance, these scripts provide reliable automation solutions.

## Features

- **User Synchronization**: Sync SQL Server users and logins across Always-On Availability Group nodes
- **Automation Ready**: Scripts designed for scheduled tasks and CI/CD pipelines
- **Well Documented**: Each script includes detailed help and usage examples
- **Best Practices**: Follows PowerShell and SQL Server best practices

## Prerequisites

- Windows PowerShell 5.1 or PowerShell Core 7.0+
- SQL Server Management Objects (SMO)
- Appropriate SQL Server permissions for the operations you wish to perform
- SQL Server 2012 or later (for Always-On Availability Group features)

## Installation

1. Clone this repository:
   ```powershell
   git clone https://github.com/danielfeiler/PS-SQL-ServerTools.git
   cd PS-SQL-ServerTools
   ```

2. Ensure you have the required SQL Server PowerShell modules:
   ```powershell
   Install-Module -Name SqlServer -Scope CurrentUser
   ```

3. Set execution policy if needed:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## Scripts

### Copy-SyncSQLUsersOnCluster.ps1

Copies and synchronizes SQL Server users and logins across all nodes in an Always-On Availability Group cluster.

**Purpose**: When managing SQL Server Always-On Availability Groups, user accounts and logins need to be consistent across all replicas. This script automates the synchronization process, ensuring that users, passwords, and permissions are identical on all nodes.

**Features**:
- Synchronizes SQL logins across all AG nodes
- Preserves SIDs to maintain consistency
- Handles SQL authentication logins
- Maintains role memberships and permissions

**Usage**:
```powershell
.\Copy-SyncSQLUsersOnCluster.ps1 -PrimaryServer "SQL01" -SecondaryServers "SQL02","SQL03"
```

For detailed usage and parameters, use:
```powershell
Get-Help .\Copy-SyncSQLUsersOnCluster.ps1 -Full
```

## Usage Examples

### Sync Users in an Availability Group

```powershell
# Sync all users from primary to secondary replicas
.\Copy-SyncSQLUsersOnCluster.ps1 -PrimaryServer "PRIMARY-SQL" -SecondaryServers "SECONDARY-SQL1","SECONDARY-SQL2"
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Best Practices

- Always test scripts in a non-production environment first
- Review and understand script functionality before execution
- Ensure you have appropriate backups before making changes
- Use appropriate SQL Server accounts with necessary permissions
- Review logs and output after script execution

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions:
- Open an issue in this repository
- Check existing issues for solutions
- Review script documentation using `Get-Help`

## Roadmap

Future scripts and enhancements planned:
- Database backup automation
- Performance monitoring scripts
- Index maintenance utilities
- Database migration tools

## Acknowledgments

- Microsoft SQL Server team for excellent PowerShell module support
- PowerShell community for best practices and inspiration

---

**Note**: These scripts are provided as-is. Always review and test in your environment before using in production.
