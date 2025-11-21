# 🐧 Linux VM with Application Security Groups - PROJECT SUMMARY

## 📈 PROJECT OVERVIEW
**Architecture Pattern**: Application-Centric Network Security  
**Primary Use Case**: Micro-segmented web server deployment  
**Complexity Level**: Intermediate  
**Deployment Time**: ~10-12 minutes  

## 🎯 BUSINESS VALUE
- **Enhanced Security**: Application-layer network segmentation
- **Operational Simplicity**: Intuitive security rule management
- **Scalability**: Dynamic security group membership
- **Compliance**: Meets zero-trust network security principles

## 🏗️ TECHNICAL ARCHITECTURE

### Core Components
- **Ubuntu Linux VM**: LTS version with configurable sizing options
- **Application Security Group**: Logical grouping for web servers
- **NGINX Web Server**: Automatically installed and configured
- **Network Security Group**: ASG-enhanced security rules
- **Custom Script Extension**: Automated software deployment
- **Public IP**: Internet connectivity for web services

### Application Security Group Benefits
```
Traditional NSG (IP-based):
├── Rules tied to specific IP addresses
├── Manual updates when VMs change
├── Network-centric security model
└── Complex rule management

ASG-Enhanced NSG (Application-based):
├── Rules tied to application roles
├── Automatic updates with VM membership
├── Application-centric security model
└── Intuitive rule management
```

### Security Architecture
- **Web Tier ASG**: Contains web servers (NGINX VMs)
- **App Tier ASG**: Future app servers (expandable)
- **DB Tier ASG**: Future database servers (expandable)
- **Management ASG**: Administrative access VMs

## 🚀 DEPLOYMENT AUTOMATION

### Prerequisites
- SSH key pair or password for authentication
- Resource group with network permissions
- Optionally: Custom NGINX installation script

### Authentication Options
```bash
# Option 1: SSH Key (Recommended)
ssh-keygen -t rsa -b 2048 -f ~/.ssh/azure_vm_key
az deployment group create \
  --resource-group rg-linux-asg \
  --template-file azuredeploy.bicep \
  --parameters adminPasswordOrKey="$(cat ~/.ssh/azure_vm_key.pub)" \
               authenticationType="sshPublicKey"

# Option 2: Password Authentication
az deployment group create \
  --resource-group rg-linux-asg \
  --template-file azuredeploy.bicep \
  --parameters adminPasswordOrKey="SecureP@ssw0rd123!" \
               authenticationType="password"
```

### Post-Deployment Verification
1. SSH connectivity test
2. NGINX service status check
3. Web server HTTP response validation
4. ASG membership confirmation

## 📊 PERFORMANCE CHARACTERISTICS

### VM Performance Options
- **Overlake Series**: Latest Intel processors, optimized performance
- **Non-Overlake Series**: Standard processors, cost-effective
- **Burstable**: Variable performance for development workloads

### Web Server Performance
- **NGINX Concurrent Connections**: 1,024 (default configuration)
- **HTTP Requests/Second**: 1,000-10,000 (VM size dependent)
- **Static Content**: Optimized for high throughput
- **Memory Usage**: ~10-50MB baseline

### Network Performance
- **SSH Latency**: 5-50ms (internet dependent)
- **HTTP Response Time**: 1-10ms (local processing)
- **Bandwidth**: Up to 25 Gbps (VM size dependent)

## 💰 COST ANALYSIS

### Monthly Cost Breakdown (East US)
- **VM Compute**: $30-300/month (size dependent)
- **VM Storage (OS)**: ~$4-8/month (Standard SSD)
- **Public IP**: ~$4/month (Standard tier)
- **Application Security Group**: No additional cost
- **Network Security Group**: No additional cost
- **Bandwidth**: $0.087/GB outbound

### Cost Optimization Strategies
- **Development**: Use B-series burstable VMs
- **Production**: Reserved instances for consistent workloads
- **Scaling**: Implement auto-scaling based on demand
- **Monitoring**: Set up cost alerts and budgets

## 🔍 MONITORING & TROUBLESHOOTING

### Key Metrics
- VM CPU, memory, and disk utilization
- NGINX active connections and request rate
- Application Security Group flow logs
- SSH connection attempts and success rate

### Monitoring Commands
```bash
# VM Resource Monitoring
htop                    # Real-time system monitoring
free -h                 # Memory usage
df -h                   # Disk usage
iostat 1 5              # I/O statistics

# NGINX Monitoring
sudo systemctl status nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
curl -I http://localhost  # Health check
```

### Common Issues & Solutions
- **SSH Access Denied**: Check NSG rules and VM firewall
- **NGINX Not Starting**: Verify configuration with `nginx -t`
- **Web Server Not Responding**: Check service status and logs
- **ASG Rules Not Working**: Verify VM-to-ASG association

## 🔒 SECURITY FEATURES

### Application Security Groups
- **Web Servers ASG**: HTTP/HTTPS traffic allowed
- **SSH Management ASG**: Administrative access
- **Dynamic Membership**: VMs automatically inherit rules

### Network Security Rules
```bash
# Example ASG-based rules
Allow-HTTP-To-WebServers: 
  Source: Internet
  Destination: webServersASG
  Port: 80, 443

Allow-SSH-To-WebServers:
  Source: AdminNetworks
  Destination: webServersASG
  Port: 22
```

### SSH Security Hardening
- Key-based authentication (recommended)
- Disable password authentication for production
- Implement fail2ban for brute-force protection
- Configure custom SSH port (optional)

## 🔄 SCALING & EXPANSION

### Horizontal Scaling
- Deploy additional VMs with same ASG membership
- Implement load balancer for traffic distribution
- Use VM Scale Sets for automatic scaling
- Configure health probes for availability

### Application Security Group Expansion
```bash
# Add database tier
Create DB-Servers ASG → Add database VMs → Configure MySQL/PostgreSQL rules

# Add application tier  
Create App-Servers ASG → Add backend VMs → Configure API rules

# Add monitoring tier
Create Monitoring ASG → Add monitoring VMs → Configure metrics collection
```

## 🏗️ ADVANCED CONFIGURATIONS

### NGINX Customization
```bash
# SSL/TLS Configuration
sudo certbot --nginx -d example.com
sudo nginx -t && sudo systemctl reload nginx

# Custom Configuration
sudo nano /etc/nginx/sites-available/default
sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
```

### Security Enhancements
```bash
# Install and configure UFW (Uncomplicated Firewall)
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'

# Install fail2ban for SSH protection
sudo apt install fail2ban -y
sudo systemctl enable fail2ban
```

## 📋 PRODUCTION READINESS CHECKLIST

### Pre-Deployment
- [ ] Define application security group strategy
- [ ] Plan SSH key management and rotation
- [ ] Configure monitoring and alerting
- [ ] Establish backup procedures

### Security Hardening
- [ ] Disable password authentication (use keys only)
- [ ] Configure fail2ban for SSH protection
- [ ] Implement UFW firewall rules
- [ ] Set up automated security updates

### Operational Excellence
- [ ] Configure log aggregation and analysis
- [ ] Implement health monitoring and alerting
- [ ] Set up automated backup procedures
- [ ] Document incident response procedures

### Performance Optimization
- [ ] Tune NGINX configuration for workload
- [ ] Configure appropriate VM sizing
- [ ] Implement caching strategies
- [ ] Set up content delivery network (CDN)

---

*This template demonstrates modern network security patterns using application-centric security policies for micro-segmentation and zero-trust networking principles.*