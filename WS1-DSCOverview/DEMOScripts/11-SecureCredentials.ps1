#Secure Credentials require certificates
#We will use self-signed certs for this dmeo
#Goto S16-01 and run these commands
$cert = New-SelfSignedCertificate -Type DocumentEncryptionCertLegacyCsp -DnsName 'S16-01.cloud.lab' -HashAlgorithm SHA256
# export the public key certificate
$cert | Export-Certificate -FilePath "C:\DemoScripts\DscPublicKey.cer" -Force

# add copy over pssession?

#Copy the cert to this authoring station and generate the config data
#Thumbprint is from the target node
#Get it using Get-ChildItem Cert:\LocalMachine\My
#Or get it through x509certificate2 class
[System.Security.Cryptography.X509Certificates.X509Certificate2]::new('C:\DemoScripts\DscPublicKey.cer').Thumbprint

$ConfigData= @{ 
    AllNodes = @(     
        @{  
            # The name of the node we are describing 
            NodeName = "S16-01" 

            # The path to the .cer file containing the 
            # public key of the Encryption Certificate 
            # used to encrypt credentials for this node 
            CertificateFile = "C:\DemoScripts\DscPublicKey.cer" 


            # The thumbprint of the Encryption Certificate 
            # used to decrypt the credentials on target node 
            Thumbprint = "20BAC25353DE4C94C39006F85E0B25BC19D26AFF" 
        }; 
    )    
}

Configuration UserDemo
{
    param (
        [pscredential] $Credential
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Node $AllNodes.NodeName
    {
        User UserDemo
        {
            UserName = $Credential.UserName
            Password = $Credential
            Description = "local account"
            Ensure = "Present"
            Disabled = $false
            PasswordNeverExpires = $true
            PasswordChangeRequired = $false
        }

        # v1
        # LocalConfigurationManager 
        # { 
        #      CertificateId = $node.Thumbprint 
        # }
    }
}

# meta.mof v2
[dsclocalconfigurationmanager()]
configuration LCM {
    Node $AllNodes.NodeName {
        Settings {
            CertificateID = $node.Thumbprint
        }
    }
}
LCM -ConfigurationData $ConfigData -OutputPath C:\DemoScripts\UserDemo

#Compiling this configuration will pass
UserDemo -OutputPath C:\DemoScripts\UserDemo -Credential (Get-Credential) -ConfigurationData $ConfigData

#enact meta config first to ensure that the LCM is aware of the certificate to decrypt
Set-DscLocalConfigurationManager -Path C:\DemoScripts\UserDemo -ComputerName S16-01

#Check the MOF before enacting it. The password should be encrypted
psEdit C:\DemoScripts\UserDemo\S16-01.MOF

#enact resource configuration
Start-DscConfiguration -Path C:\DemoScripts\UserDemo -ComputerName S16-01 -Verbose -Wait -Force
