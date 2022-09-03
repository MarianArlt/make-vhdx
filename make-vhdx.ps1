<#
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License
as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.
#>

# GUI to choose disk path
function PickFolder {
    # Access built-in library
    Add-Type -AssemblyName System.Windows.Forms

    # Initialize pop-up
    $picker = New-Object System.Windows.Forms.FolderBrowserDialog
    # Powershell 7
    if ($path_picker.InitialDirectory) {
        $path_picker.InitialDirectory = "C:\"
    }
    # Powershell 5
    if ($path_picker.RootFolder) {
        $path_picker.RootFolder = "MyComputer"
        $path_picker.SelectedPath = "C:\"
    }

    # Call and save choice
    if ($picker.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $picker.SelectedPath
    }
}

# GUI to choose virtual machine
function PickMachine {
    # Access built-in library
    Add-Type -AssemblyName System.Windows.Forms

    # Parent window
    $select = New-Object system.Windows.Forms.Form
    $select.ClientSize = '400,240'
    $select.text = "Machine picker"
    $select.BackColor = '#ffffff'

    # Combo box
    $list = New-Object system.Windows.Forms.ComboBox
    $list.text = ""
    $list.width = 300
    $list.location = New-Object System.Drawing.Point(50,100)
    $list.Font = 'Microsoft Sans Serif, 12'
    Get-VM | Select-Object -ExpandProperty Name | ForEach-Object {[void] $list.Items.Add($_)}

    # Label
    $label = New-Object system.Windows.Forms.Label
    $label.text = "Select a virtual machine:"
    $label.width = (400-2*47)
    $label.location = New-Object System.Drawing.Point(47,60)
    $label.Font = 'Microsoft Sans Serif, 12'

    # Confirmation button
    $button = New-Object System.Windows.Forms.Button
    $button.text = "OK"
    $button.width = 100
    $button.location = New-Object System.Drawing.Point(250,180)
    $button.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $select.AcceptButton = $button

    # Attach everything to parent window
    $select.Controls.Add($list)
    $select.Controls.Add($label)
    $select.Controls.Add($button)

    # Initialize
    $select.Topmost = $true
    $select_result = $select.ShowDialog()

    # Save choice
    if ($select_result -eq [System.Windows.Forms.DialogResult]::OK) {
        $vm_name = $list.SelectedItem
        $disks_path = Get-VM -Name $vm_name | Select-Object -ExpandProperty Path
        return $vm_name, $disks_path
    }
}

Write-Host "`n`n    Create several virtual disks for use with Hyper-V and optionally add them to an existing machine.`n    The guest OS can be running while executing this script.`n    The executing user needs to have administrative privileges.`n    Defaults can be accepted by pressing [ENTER]`n    Copyright 2022, Marian Arlt, All rights reserved`n`n"

# Prompt for disk names
$disks_basename = Read-Host "Please enter a name for your disks. For example 'vm-raid5-disk'.`nA running number in the format of '-n' will get appended automatically (Default: 'Disk')"
if (!$disks_basename) {
    $disks_basename = "disk"
}
Write-Host "> The first disk will be called: $disks_basename-1"

# Prompt for quantity
$disks_total = Read-Host "`nHow many disks do you want to create? (Default: 2)"
if (!$disks_total) {
    $disks_total = 2
}
Write-Host "> $disks_total disks will be created."

# Prompt for size
$disks_equal = Read-Host "`nShould these disks all be of the same size? (Default: Yes)"
if ($disks_equal -like "N*") {
    $unequal_size = @()
    for ($i = 1; $i -le $disks_total; $i++) {
        $unequal_size_current = Read-Host "`nEnter size for $disks_basename-$i (Default: 2GB)"
        if (!$unequal_size_current) {
            $unequal_size_current = "2GB"
        }
        $unequal_size += $unequal_size_current
    }
} else {
    $equal_size = Read-Host "`nEnter the size of the disks (Default: 2GB)"
    if (!$equal_size) {
        $equal_size = "2GB"
    }
    Write-Host "> The $disks_total disks will all be of $equal_size."
}

# Prompt for path
$add_to_vm = Read-Host "`nShould the created disks be attached to an existing virtual machine? (Default: No)"
if ($add_to_vm -like "Y*") {

    $vm_name, $disks_path = PickMachine

} else {

    Read-Host "Press [ENTER] to select a folder to save the new disks to"
    $disks_path = PickFolder

}
Write-Host "> The disks will be created in $disks_path"

# Prompt for initialization
$init = Read-Host "`nDo you want to initialize these disks? (Default: Yes)"

# Create disks
for ($i=1; $i -le $disks_total; $i++) {
    $full_path = "$disks_path\Virtual Hard Disks\$disks_basename-$i.vhdx"
    
    if ($unequal_size) {
        New-VHD -Path $full_path -SizeBytes $unequal_size[$i-1]
    } else {
        New-VHD -Path $full_path -SizeBytes $equal_size
    }
    if ($?) {
        Write-Host "> Successfully created $disks_basename-$i`n"
    }

    # Initialize
    if ($init -notlike "N*") {
        Mount-VHD -Path $full_path
        $disk = Get-VHD -Path $full_path
        Initialize-Disk $disk.DiskNumber
        if ($?) {
            Write-Host "> Successfully initialized $disks_basename-$i`n"
        }
        Dismount-VHD -Path $full_path
    }

    # Attach to virtual machine
    if ($vm_name) {
        Add-VMHardDiskDrive -VMName $vm_name -Path $full_path
    }
}