<#
.SYNOPSIS
    Displays the contents of a folder in a tree format.

.DESCRIPTION
    This script takes a folder path as input and displays its contents in a hierarchical tree structure,
    showing folders and files with appropriate tree characters (|-- for items).

.PARAMETER FolderPath
    The path to the folder whose contents should be displayed in tree format.

.PARAMETER MaxDepth
    The maximum depth to traverse. Default is 3 levels deep. Use -1 for unlimited depth.

.PARAMETER ShowHidden
    Include hidden files and folders in the output.

.PARAMETER FilesOnly
    Show only files (exclude folders from the tree).

.PARAMETER FoldersOnly
    Show only folders (exclude files from the tree).

.EXAMPLE
    .\Show-FolderTree.ps1 -FolderPath "C:\MyProject"
    
.EXAMPLE
    .\Show-FolderTree.ps1 -FolderPath "C:\MyProject" -MaxDepth 2 -ShowHidden

.EXAMPLE
    Show-FolderTree -FolderPath ".\src" -FilesOnly
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$FolderPath,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxDepth = 10,
    
    [Parameter(Mandatory = $false)]
    [switch]$ShowHidden,
    
    [Parameter(Mandatory = $false)]
    [switch]$FilesOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$FoldersOnly
)

function Show-FolderTree {
    param(
        [string]$Path,
        [string]$Prefix = "",
        [int]$CurrentDepth = 0,
        [int]$MaxDepth,
        [bool]$ShowHidden,
        [bool]$FilesOnly,
        [bool]$FoldersOnly,
        [bool]$IsLast = $false
    )
    
    # Check if we've reached the maximum depth
    if ($MaxDepth -ne -1 -and $CurrentDepth -ge $MaxDepth) {
        return
    }
    
    try {
        # Get all items in the current directory
        $items = Get-ChildItem -Path $Path -ErrorAction Stop
        
        # Filter items based on parameters
        if (-not $ShowHidden) {
            $items = $items | Where-Object { -not $_.PSIsContainer -or -not ($_.Attributes -band [System.IO.FileAttributes]::Hidden) }
            $items = $items | Where-Object { $_.PSIsContainer -or -not ($_.Attributes -band [System.IO.FileAttributes]::Hidden) }
        }
        
        if ($FilesOnly) {
            $items = $items | Where-Object { -not $_.PSIsContainer }
        }
        
        if ($FoldersOnly) {
            $items = $items | Where-Object { $_.PSIsContainer }
        }
        
        # Sort items: directories first, then files, both alphabetically
        $items = $items | Sort-Object @{Expression = { $_.PSIsContainer }; Descending = $true }, Name
        
        for ($i = 0; $i -lt $items.Count; $i++) {
            $item = $items[$i]
            $isLastItem = ($i -eq ($items.Count - 1))
            
            # Determine the tree characters to use
            if ($isLastItem) {
                $currentPrefix = $Prefix + "`-- "
                $nextPrefix = $Prefix + "    "
            } else {
                $currentPrefix = $Prefix + "|-- "
                $nextPrefix = $Prefix + "|   "
            }
            
            # Display the item
            if ($item.PSIsContainer) {
                Write-Host "$currentPrefix$($item.Name)/" -ForegroundColor Blue
                
                # Recursively show contents of subdirectories
                if (-not $FilesOnly) {
                    Show-FolderTree -Path $item.FullName -Prefix $nextPrefix -CurrentDepth ($CurrentDepth + 1) -MaxDepth $MaxDepth -ShowHidden $ShowHidden -FilesOnly $FilesOnly -FoldersOnly $FoldersOnly
                }
            } else {
                # Color files differently based on extension
                $color = switch -Regex ($item.Extension.ToLower()) {
                    '\.(exe|dll|msi)$' { 'Red' }
                    '\.(ps1|cmd|bat)$' { 'Green' }
                    '\.(txt|md|log)$' { 'Yellow' }
                    '\.(cs|cpp|h|hpp|c)$' { 'Cyan' }
                    '\.(yml|yaml|json|xml)$' { 'Magenta' }
                    default { 'White' }
                }
                
                $sizeInfo = ""
                if ($item.Length -gt 0) {
                    $size = $item.Length
                    if ($size -gt 1MB) {
                        $sizeInfo = " ({0:N1} MB)" -f ($size / 1MB)
                    } elseif ($size -gt 1KB) {
                        $sizeInfo = " ({0:N1} KB)" -f ($size / 1KB)
                    } else {
                        $sizeInfo = " ($size B)"
                    }
                }
                
                Write-Host "$currentPrefix$($item.Name)$sizeInfo" -ForegroundColor $color
            }
        }
    }
    catch {
        Write-Host "$Prefix|-- [Error: Access Denied or Path Not Found]" -ForegroundColor Red
    }
}

# Main execution
try {
    # Resolve the path to handle relative paths
    $resolvedPath = Resolve-Path -Path $FolderPath -ErrorAction Stop
    
    # Display the root folder
    $rootName = Split-Path -Leaf $resolvedPath
    if ([string]::IsNullOrEmpty($rootName)) {
        $rootName = $resolvedPath
    }
    
    Write-Host "$rootName/" -ForegroundColor Blue
    
    # Show the tree
    Show-FolderTree -Path $resolvedPath -MaxDepth $MaxDepth -ShowHidden $ShowHidden.IsPresent -FilesOnly $FilesOnly.IsPresent -FoldersOnly $FoldersOnly.IsPresent
    
    Write-Host ""
    Write-Host "Tree display completed." -ForegroundColor Gray
}
catch {
    Write-Error "Error: Could not access the specified folder path '$FolderPath'. $($_.Exception.Message)"
    exit 1
}
