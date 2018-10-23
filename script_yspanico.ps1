# use TLS protocol
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# import module PSSQLite
Import-Module PSSQLite

# (64 bit) System.Data.SQLite ADO.NET data provider in this directory 
Add-Type -Path "C:\Program Files\System.Data.SQLite\2010\bin\System.Data.SQLite.dll"

$Token = 'yspanico:9edabc7e1d6a687fcac615e917be49a67277b43b'
$Base64Token = [System.Convert]::ToBase64String([char[]]$Token);
$Headers = @{
    Authorization = 'Basic {0}' -f $Base64Token;
    };


################### declare my Functions ##################

# 1 - Function Get-Number-of-pages
function Get-Number-of-pages {
 $ese = $args[0]

if ($ese) {
   foreach ($reg in $ese) {
     if ($reg.split(";")[1].Contains("last")) {
        $count = $reg.split(";")[0].Replace("<","").Replace(">","").Split("&").Count
        return $reg.split(";")[0].Replace("<","").Replace(">","").Split("&")[$count-1].split("=")[1] 
        break
     }
   }

} else {
      return 1
    }
}

# 2 - Function get file from GitHUB Repository
function DownloadFilesFromRepo {
Param(
    [string]$Owner,
    [string]$Repository,
    [string]$Path,
    [string]$DestinationPath
    )
    $baseUri = "https://api.github.com/"
    $args = "repos/$Owner/$Repository/contents/$Path"
    $wr = Invoke-WebRequest -Uri $($baseuri+$args) -Headers $Headers
    
    # get the content as pages object with all fields name, path, url, etc / in JSON format  
    $objects = $wr.Content | ConvertFrom-Json

    # if content type = file --> get download_url which contains the url to get the file
    $files = $objects | where {$_.type -eq "file"} | Select -exp download_url
  
    # check if the all the elements in the $DestinationPath exist -> If YES jump this step
    if (-not (Test-Path $DestinationPath)) {
        # OTHERWISE Destination path does not exist, let's create it
        try {
            New-Item -Path $DestinationPath -ItemType Directory -ErrorAction Stop
        } catch {
            throw "Could not be possible create path '$DestinationPath'!"
        }
    }
          
    # for each entry in download_url (https://raw.githubusercontent.com/$Owner/$Repository/.../$path?token=*****) 
    foreach ($file in $files) {
       $fileDestination = Join-Path $DestinationPath (Split-Path $file.Split("?")[0] -Leaf)
        try {
            # create a file json with the download
            #$arrayjson = Invoke-WebRequest -Uri $file -OutFile $fileDestination -ErrorAction Stop -Verbose # -Headers $Headers
            
            # create the json object to manipulate
            $arrayjson = Invoke-WebRequest -Uri $file -ErrorAction Stop #-Verbose  -Headers $Headers
             
            # convert json file in an object to be manipulated
            $users_obj = $arrayjson | ConvertFrom-Json
           
            echo $users_obj.login
                       
        } catch {
            throw "Unable to download '$($file.path)'"
        }
    }
}

# 3 - Upload file on Repository Github
function UploadFilesToRepo {
Param(
    [string]$Owner,
    [string]$Repository,
    [string]$Path,
    [string]$SourcePath
    )
    $baseUri = "https://api.github.com/"
    $args = "repos/$Owner/$Repository/contents/$Path"
    $putfile = Invoke-WebRequest -Uri $($baseuri+$args) -Headers $Headers 
    
    # get the content as pages object with all fields name, path, url, etc / in JSON format  
    $objects = $putfile.Content | ConvertFrom-Json

    echo $objects


    # if content type = file --> get download_url which contains the url to get the file
    $files = $objects | where {$_.type -eq "file"} | Select -exp download_url
  
    # check if the all the elements in the $DestinationPath exist -> If YES jump this step
    if (-not (Test-Path $DestinationPath)) {
        # OTHERWISE Destination path does not exist, let's create it
        try {
            New-Item -Path $DestinationPath -ItemType Directory -ErrorAction Stop
        } catch {
            throw "Could not be possible create path '$DestinationPath'!"
        }
    }
          
    # for each entry in download_url (https://raw.githubusercontent.com/$Owner/$Repository/.../$path?token=*****) 
    foreach ($file in $files) {
       $fileDestination = Join-Path $DestinationPath (Split-Path $file.Split("?")[0] -Leaf)
        try {
            # create a file json with the download
            #$arrayjson = Invoke-WebRequest -Uri $file -OutFile $fileDestination -ErrorAction Stop -Verbose # -Headers $Headers
            
            # create the json object to manipulate
            $arrayjson = Invoke-WebRequest -Uri $file -ErrorAction Stop #-Verbose  -Headers $Headers
             
            # convert json file in an object to be manipulated
            $users_obj = $arrayjson | ConvertFrom-Json
           
            echo $users_obj.login
                       
        } catch {
            throw "Unable to download '$($file.path)'"
        }
    }
}

# 4 - Create table commits into SQLite DB
function create_DB {
 $local_path = $args[0] # .\sqlite\db\github.db

 if (Test-Path $local_path) {
    Write-Host "DB already exists. Located in $local_path "
    
 } else {
   Write-Host "DB created in $local_path"
   
   $create_query =    "CREATE TABLE commits (
                                    sha TEXT,
                                    date TEXT,
                                    author TEXT,
                                    message TEXT,
                                    is_external INTEGER
                                    )"
   $cq_result = Invoke-SqliteQuery -DataSource $local_path -Query $create_query 
 }

}

# 5 - Insert data into table commits into SQLite DB
function update_DB () {
$qupload = $args[0]

#path DB 
$db_path = "C:\sqlite\db\github.db"
           
# create a connection to database
$con = New-Object -TypeName System.Data.SQLite.SQLiteConnection

# create the connection string
$con.ConnectionString = "Data Source=$db_path" 
# open the connection
$con.Open()

#create a SQL statement in a command 
$sql = $con.CreateCommand()
$sql.CommandText = $qupload

# execute the query and close the connection to the DB
$sql.ExecuteNonQuery()
$sql.Dispose()
$con.Close()
}

# 5 - Insert escape character for SQLite
function Replacements () {
$qr = $args[0]
return 'sostituzione: ' + $qr.Replace('"','""').Replace('`','``').replace("’","’’")
}

################### Main environment ######################

# Create DB
create_DB ("C:\sqlite\db\github.db")

# get list of all members Bending Spoons -> file members.json
$members = @(DownloadFilesFromRepo "BendingSpoonsTalent" "github-challenge-yspanico" "assets/members.json" "C:\sqlite\db")

# get list of all commits from GitHUB -> only Repository MASTER
# GET /repos/:owner/:repo/commits
#

$url_base = 'https://api.github.com/repos/BendingSpoons/katana-swift'
$branch = 'master'
$per_page = 100
$until = '2018-06-27T23:59:59Z'
$page = 1

$urlcommit = "$url_base/commits?sha=$branch&per_page=$per_page&until=$until&page=$page" 

$getheaders = Invoke-WebRequest -Headers $Headers -Uri $urlcommit -Method Get 
$split = @($getheaders.Headers.Link.Split(","))

$numpages = Get-Number-of-pages($split)
echo "numero di pagine di commit: $numpages"
#$numpages = 1 

# Creo i file json (5 commit per file)
$y = 0
$add_all_page = ""

 while($y -ne $numpages) {
    $z = $y+1
    $newurl = "$url_base/commits?sha=$branch&per_page=$per_page&until=$until&page=$z" 
    $pathfile = "C:\sqlite\db\commit_yspanico_$z.json"
    
    echo "Pagina $z : Create JSON in $pathfile"

    # Create a JSON file on local PC
    #Invoke-RestMethod -Headers $Headers -Uri $newurl -Method Get -OutFile $pathfile

    # Create a JSON object
    $yspanicojson = Invoke-RestMethod -Headers $Headers -Uri $newurl -Method Get 
   
    #create empty array
    $add = @()
        
    # read the values in the users_obj
    foreach ($r in $yspanicojson) {
  
    ####### check if author is present members.json ##################
    $a = 0
    $b = 0
    
    foreach ($n in $members) {
        if (($n -ceq $r.author.login) -and ($r.author.login)) {
            # there is a match 
            $a = 1
            break
        } 
    }
    $is_external = 1-[int]($a -or $b)
    ####### end find author in members.json ##############
    $mes_parsed = Replacements($r.commit.message )
    #echo $mes_parsed
    $author_parsed = ""

   # echo $r.author.login
   # echo $author_parsed

    if ($r.author.login -ceq $null) {
        $author_parsed = "External contribution"
     } else {
      $author_parsed = $r.author.login
     }

    $add += '("' + $r.sha + '","' + $r.commit.author.date + '","' + $author_parsed + '","' + $mes_parsed + '",' + $is_external + ")," + $nl

     # problema senza convertire "" or ''
    #$add += "(" + $r.sha.Replace($r.sha, '"' + $r.sha + '"') + ", " + $r.commit.author.date.Replace($r.commit.author.date, '"' + $r.commit.author.date + '"') + ", " + $r.author.login + ", " + $mes_parsing + ", " + $is_external + ")," + $nl

    }
    #echo $add
    #echo $members
   
    $add_all_page += $add
  
    $y++

}
  #echo "--------------------------------   primo testo NO CONVERTITO: add[ALL]"
  #echo $add_all_page
  #echo "--------------------------------   secondo testo CONVERTITO: add_all_page "
  #echo $add_all_page | ConvertTo-json 
  #echo $insert| ConvertTo-Xml -Depth 100 

  $qconvert = $add_all_page #| convertTo-Json -Depth 100

  $query_temp = "INSERT INTO commits (sha, date, author, message, is_external) VALUES " + $qconvert 
  #$insert = $query_temp -replace ".$",";"
  $insert = $query_temp.Substring(0,$query_temp.Length-1) + ";"
  #echo "--------------------------------   LAST PRINTER TEXT"
  #echo $insert
  


    if (update_DB ($insert)) {
        try {
            echo "update completed: PAGINA $z"
            #echo $insert
        } catch {
            throw "DB Insert error"
            break
        }
    }



# Upload file on */BendingSpoonsTalentgithub-challenge-yspanico
# $url_upload = $url_base


#################### to be completed ###################

<#  Here I wanted to create two functions for both "create" and "upload" files directly on GitHub
    but the time was terminated! Sorry! I wasn't able to test this.

$args = "repos/$Owner/$Repository/contents/$Path"
path = github-challenge-yspanico/

file1 - github.db 
file2 - script_yspanico.ps1

$message1 = "Upload SQLite DB as required by test described in Repository */BendingSpoonsTalentgithub-challenge-yspanico"
$content1 = /github.db 
$message2 = "Upload script as required by test described in Repository */BendingSpoonsTalent/github-challenge-yspanico"
$content2 = /script_yspanico.ps1


$pathfile = "C:\sqlite\db\github.db"

$Text = [System.IO.File]::ReadAllText($pathfile)

# Convert the string to UTF-8 bytes
$UTF8Bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)

# Encode the UTF-8 bytes as a Base64 string
$Base64String = [System.Convert]::ToBase64String($UTF8Bytes)

$Body = @{
    message = "Upload SQLite DB as required by test described in Repository */BendingSpoonsTalentgithub-challenge-yspanico";
    content = $Base64String;
    } | ConvertTo-Json;


    Invoke-RestMethod -Uri $($baseuri+$args) -Headers $Headers  -Body $Body -Method Put 
    

#>