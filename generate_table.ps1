function import-table{
    param(
        $fileLocation,
        $generateScript=$true,
        $app='dc-application-ionic-react',
        $tableName='Applicant',
        $schema='salesforce'
    )
    $tableRows = Import-Csv -Path $fileLocation
    if($tableRows.Count -eq 0)
    {
        Write-Host('No rows in table')
        return $null;
    }

    $deleteCommand = "DROP TABLE IF EXISTS $schema.$tableName"
    $boilerPlate = "CREATE TABLE $schema.$tableName"

    [System.Collections.ArrayList]$argumentsList = @();
    foreach($row in $tableRows)
    {
        $string = "$($row.Identifier) $($row.Type)"

        if($row.Unique -eq 'yes'){
            $string+= ' UNIQUE'
        }

        if($row.required -eq 'yes'){
            $string+= ' NOT NULL'
        }
        #write-host($string)
        $null = $argumentsList.Add($string);
    }

    $arguments = "`($($argumentsList -join ',')`)"

    $command = $boilerPlate + $arguments;

    if($generateScript)
    {
        if($saveToFile)
        {
            Write-Host("saving create_$tableName.psql");
            $command | Out-File -FilePath "./create_$tableName.psql" -Encoding utf8
        }else{
            return @($deleteCommand,$command);
        }
    }else
    {
        heroku pg:psql -a $app -c $deleteCommand
        heroku pg:psql -a $app -c $command
    }
}

function import-tables{
    param($path,
          $generateScript=$true)
    $tables = Get-ChildItem -Path $path -Filter '*.csv'
    [System.Collections.ArrayList] $commands = @();
    $null = $commands.Add('CREATE SCHEMA IF NOT EXISTS salesforce')
    foreach($table in $tables){
        $tablePath = $table.FullName
        $tableName = (($table.name -split '-')[1] -replace '.csv','').trim()
        $command = import-table -fileLocation $tablePath -tableName $tableName -generateScript $generateScript
        $null = $commands.AddRange($command);
    }

    $script = ($commands -join ";`n") + ";"
    $script | Out-File -FilePath "./create_tables.psql" -Encoding utf8
}