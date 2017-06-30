Param($password,$hostname, $port=1433, $dbpath)

function Get-DbArgs {
    Param($dbpath)
    
    $dbpathArg = ""
    $dbArg = ""

    if($dbpath -ne "")
    {
    
        #GENERATE
        $files = Get-ChildItem $dbpath -Filter *.mdf
        $arr = new-object System.String[](0)
    
        foreach($file in $files)
        {
            $mdf = "C:\\temp\\" + $file.Name
            $ldf = "C:\\temp\\" + $file.BaseName + ".ldf"
            $arr += "{'dbName':'" + $file.BaseName + "','dbFiles':['" + $mdf + "','" + $ldf + "']}"
        }

        $dbArg = "-e attach_dbs=`"[" + ($arr -join ",") +  "]`""
        $dbpathArg = "-v " + $dbpath + ":C:\temp"
        
    }

    Write-Output ($dbpathArg + " " + $dbArg)
}

function Update-Hosts {
    Param($hostname, $container)

    $ip = docker inspect --format "{{ .NetworkSettings.Networks.nat.IPAddress }}" $container
    $hostsFile = $env:windir + "\system32\drivers\etc\hosts"
    $content = (Get-Content $hostsFile)
    $regex = "(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(\s+|t+)(" + $hostname + "(\s+|\t+)|" + $hostname + "$)"
    $value = $ip + "`t`t" + $hostname + "`t`t"

    if($content -imatch $regex) 
    {
        $content = $content -ireplace $regex, $value
    }
    else 
    {
        $content = $content + $value + "# docker sqlexpress host"
    }
    
    Out-File -FilePath $hostsFile -InputObject $content

    Write-Host ("Hosts file updated with new configuration:" + "`n" + $value)
}

if($hostname -imatch '^localhost$')
{
    Write-Host "ERROR: You cannot use 'localhost' as a hostname."
    exit
}

$container = docker ps -q --filter ("name=" + $hostname)

#STOP AND REMOVE ACTIVE CONTAINER
if($container -ne $null)
{
    Write-Host ("Stopping docker container '" + (docker stop $container) + "'...")
    Write-Host ("Removing docker container '" + (docker rm $container) + "'...")
}

#GENERATE RUN ARGUMENTS
$nameArgs = "--name " + $hostname
$dbArgs = Get-DbArgs -dbpath $dbpath
$portArg = "-p " + $port + ":1433"
$passwordArg = "-e sa_password=" + $password
$eulaArg = "-e ACCEPT_EULA=Y"
$image = "microsoft/mssql-server-windows-express"
$cmd = "docker run -d " + ($nameArgs, $portArg, $passwordArg, $dbArgs, $eulaArg, $image) -join " "

Write-Host ("Running '" + $image + "'...")

Invoke-Expression $cmd

#GET NEW CONTAINER
$container = docker ps -q --filter ("name=" + $hostname)

if($container -eq $null)
{
    exit
}

#UPDATE HOSTS FILE
Update-Hosts -hostname $hostname -container $container