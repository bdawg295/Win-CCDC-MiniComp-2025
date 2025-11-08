# Win-CCDC-MiniComp-2025
Small hardening script for RIT CCDC mini comp 2025

Remember to run as admin, don't run as DC

if want to dryrun add -DryRun between service and Keepadmins

# Moon Landing (IIS)
```pwsh
powershell -ep bypass -c "iex (iwr -UseB 'https://raw.githubusercontent.com/bdawg295/Win-CCDC-MiniComp-2025/main/harden.ps1'); harden -Role IIS -KeepAdmins 'fathertime','chronos','aion','kairos','drwho','martymcfly','arthurdent','sambeckett' -KeepUsers 'merlin','terminator','mrpeabody','jamescole','docbrown','professorparadox','loki','riphunter','theflash','tonystark','drstrange','bartallen'"
```



# First Olympics (WINRM)
```pwsh
powershell -ep bypass -c "iex (iwr -UseB 'https://raw.githubusercontent.com/bdawg295/Win-CCDC-MiniComp-2025/main/harden.ps1'); harden -Role WINRM -KeepAdmins 'fathertime','chronos','aion','kairos','drwho','martymcfly','arthurdent','sambeckett' -KeepUsers 'merlin','terminator','mrpeabody','jamescole','docbrown','professorparadox','loki','riphunter','theflash','tonystark','drstrange','bartallen'"
```


# Silk Road (ICMP)
```pwsh
powershell -ep bypass -c "iex (iwr -UseB 'https://raw.githubusercontent.com/bdawg295/Win-CCDC-MiniComp-2025/main/harden.ps1'); harden -Role ICMP -KeepAdmins 'fathertime','chronos','aion','kairos','drwho','martymcfly','arthurdent','sambeckett' -KeepUsers 'merlin','terminator','mrpeabody','jamescole','docbrown','professorparadox','loki','riphunter','theflash','tonystark','drstrange','bartallen'"
```
