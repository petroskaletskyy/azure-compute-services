# Install IIS (web-Server) 
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# Delete the default IIS welcome page
Remove-Item -Path 'C:\inetpub\wwwroot\*' -Force

#Create a simple HTML file in the IIS root directory
New-Item -Path 'C:\inetpub\wwwroot\index.html' -ItemType File -Force -Value "<html><body><h1>Welcome to IIS on Azure. It's my custome web-page</h1></body></html>"