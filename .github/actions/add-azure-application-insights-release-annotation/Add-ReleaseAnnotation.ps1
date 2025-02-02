param(
    [parameter(Mandatory = $true)][string]$ApplicationInsightsResourceId,
    [parameter(Mandatory = $true)][string]$ReleaseName,
    [parameter(Mandatory = $false)]$ReleaseProperties = @()
)

Write-Output "Adding release annotation with the release name `"$ReleaseName`"."

$annotation = @{
    Id = [Guid]::NewGuid()
    AnnotationName = $ReleaseName
    EventTime = (Get-Date).ToUniversalTime().GetDateTimeFormats('s')[0]
    # AI only displays annotations from the "Deployment" category so this must be this string.
    Category = 'Deployment'
    Properties = ConvertTo-Json $ReleaseProperties -Compress
}

$body = (ConvertTo-Json $annotation -Compress) -replace '(\\+)"', '$1$1"' -replace "`"", "`"`""
az rest --method put --uri "$($ApplicationInsightsResourceId)/Annotations?api-version=2015-05-01" --body "$($body) "

if (!$?)
{
    exit 1
}
