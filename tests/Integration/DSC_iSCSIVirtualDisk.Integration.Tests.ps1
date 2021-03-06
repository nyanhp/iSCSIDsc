$script:dscModuleName = 'iSCSIDsc'
$script:dscResourceName = 'DSC_iSCSIVirtualDisk'

try
{
    Import-Module -Name DscResource.Test -Force -ErrorAction 'Stop'
}
catch [System.IO.FileNotFoundException]
{
    throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
}

$script:testEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:dscModuleName `
    -DSCResourceName $script:dscResourceName `
    -ResourceType 'Mof' `
    -TestType 'Integration'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')

try
{
    Assert-CanRunIntegrationTest -Verbose
}
catch
{
    Write-Warning -Message $_
    return
}

try
{
    $configFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:dscResourceName).Config.ps1"
    . $configFile

    Describe "$($script:DSCResourceName)_Integration" {
        Context 'When creating a iSCSI Virtual Disk' {
            BeforeAll {
                $script:testVirtualDisk = @{
                    Path            = Join-Path -Path $TestDrive -ChildPath 'TestiSCSIVirtualDisk.vhdx'
                    Ensure          = 'Present'
                    DiskType        = 'Dynamic'
                    SizeBytes       = 104857600
                    Description     = 'Integration Test iSCSI Virtual Disk'
                }
            }

            It 'Should compile and apply the MOF without throwing' {
                {
                    $configData = @{
                        AllNodes = @(
                            @{
                                NodeName    = 'localhost'
                                Path        = $script:testVirtualDisk.Path
                                Ensure      = $script:testVirtualDisk.Ensure
                                DiskType    = $script:testVirtualDisk.DiskType
                                SizeBytes   = $script:testVirtualDisk.SizeBytes
                                Description = $script:testVirtualDisk.Description
                            }
                        )
                    }

                    & "$($script:DSCResourceName)_Config" `
                        -OutputPath $TestDrive `
                        -ConfigurationData $configData

                    Start-DscConfiguration `
                        -Path $TestDrive `
                        -ComputerName localhost `
                        -Wait `
                        -Verbose `
                        -Force `
                        -ErrorAction Stop
                } | Should -Not -Throw
            }

            It 'should be able to call Get-DscConfiguration without throwing' {
                {
                    Get-DscConfiguration -Verbose -ErrorAction Stop
                } | Should -Not -throw
            }

            It 'Should have set the resource and all the parameters should match' {
                # Get the Rule details
                $virtualDiskNew = Get-iSCSIVirtualDisk -Path $script:testVirtualDisk.Path
                $virtualDiskNew.Path               | Should -Be $script:testVirtualDisk.Path
                $virtualDiskNew.DiskType           | Should -Be $script:testVirtualDisk.DiskType
                $virtualDiskNew.Size               | Should -Be $script:testVirtualDisk.SizeBytes
                $virtualDiskNew.Description        | Should -Be $script:testVirtualDisk.Description
            }

            AfterAll {
                # Clean up
                Remove-iSCSIVirtualDisk `
                    -Path $script:testVirtualDisk.Path
                Remove-Item `
                    -Path $script:testVirtualDisk.Path `
                    -Force
            } # AfterAll
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
