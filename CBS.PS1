#This will get the list of broken windows update. 

# CBS servicing states, as seen on https://docs.microsoft.com/en-us/archive/blogs/tip_of_the_day/tip-of-the-day-cbs-servicing-states-chart-refresher
# State                  Hex      Dec
# Absent                 0          0 
# Uninstall Pending      0x5        5 
# Resolving              0x10      16 
# Resolved               0x20      32 (Or -32 | 0xffffffe0 all composed component manifests, but broken) 
# Staging                0x30      48 
# Staged                 0x40      64 
# Superseded             0x50      80 
# Install Pending        0x60      96 
# Partially Installed    0x65     101 
# Installed              0x70     112 (Or -112 | 0xffffff90 fully installed, but broken)
# Permanent              0x80     128

#Load the CBS hive file under HKLM with the name "CBS" or switch the comment below to run against the current system
#$regPATH = "HKLM:\CBS\Packages"
$regPATH = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages" 
 
$brokenUpdates = Get-ChildItem -PATH $regPATH -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Rollup*" } #matches any Cumulative Update or Monthly Rollup
$brokenUpdates | Get-ItemProperty | Where-Object { $_.CurrentState -ne "80" -and $_.CurrentState -ne "112" -and $_.CurrentState -ne "7"} | Select-Object @{N=’Cumulative/rollup package(s) in broken state’; E={$_.PSChildName};} | Format-Table -Wrap -AutoSize
 
$brokenUpdates = Get-ChildItem -PATH $regPATH -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Package_for_KB[0-9]{7}~31bf3856ad364e35' } #matches any standalone KBs
$brokenUpdates | Get-ItemProperty | Where-Object { $_.CurrentState -ne "80" -and $_.CurrentState -ne "112" -and $_.CurrentState -ne "7"} | Select-Object @{N=’Standalone package(s) in broken state’; E={$_.PSChildName};} | Format-Table -Wrap -AutoSize  
