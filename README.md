# AWS Route 53 Multi-Region Geolocation Routing Lab

A complete step-by-step guide to deploying a multi-region, highly available microservices web application across **Tokyo (`ap-northeast-1`)** and **London (`eu-west-2`)** on AWS, featuring **Application Load Balancers (ALBs)**, **ACM SSL/TLS Certificates**, and **Amazon Route 53 Geolocation Routing**.

---

## 🏛️ Architecture Overview

```
                                  [ User Request ]
                                         │
                             ┌───────────┴───────────┐
                             │    Amazon Route 53    │
                             │ (Geolocation Routing) │
                             └─────┬───────────┬─────┘
                     Asia / Default│           │Europe
                                   ▼           ▼
                      ┌────────────────┐   ┌────────────────┐
                      │   Tokyo ALB    │   │   London ALB   │
                      │(ap-northeast-1)│   │  (eu-west-2)   │
                      └───────┬────────┘   └───────┬────────┘
                              │ HTTPS (443)        │ HTTPS (443)
                              ▼                    ▼
                      ┌────────────────┐   ┌────────────────┐
                      │  Private EC2   │   │  Private EC2   │
                      │  (Tokyo VPC)   │   │  (London VPC)  │
                      ├────────────────┤   ├────────────────┤
                      │ [Dashboard UI] │   │ [Dashboard UI] │
                      │  (Green Theme) │   │  (Blue Theme)  │
                      │       │        │   │       │        │
                      │       ▼        │   │       ▼        │
                      │   [Counting]   │   │   [Counting]   │
                      │ (Go Backend)   │   │ (Go Backend)   │
                      └────────────────┘   └────────────────┘
```

### Key Components
* **Domain:** `achn-chan.space` (Managed via Namecheap, delegated to AWS Route 53).
* **Application Subdomain:** `dashboard.achn-chan.space`.
* **Routing Rules:**
  * **Asia Traffic** ➔ Tokyo ALB (`ap-northeast-1`) → Shows Green UI.
  * **Europe Traffic** ➔ London ALB (`eu-west-2`) → Shows Blue UI.
  * **Default Fallback** ➔ Tokyo ALB (`ap-northeast-1`).
* **Security & Isolation:** Backend EC2 instances reside strictly in **Private Subnets** with egress-only internet via **NAT Gateways**. Inbound traffic is accepted solely from the regional ALB.

---

## 📁 Repository Structure

```
.
├── tokyo-dashboard/              # Tokyo Frontend (Green Gradient Theme)
│   ├── assets/
│   │   ├── index.html            # Tokyo Header & UI
│   │   ├── styles.css            # Green Theme (#34a853)
│   │   └── app.js                # Vanilla JS real-time counter polling
│   ├── Dockerfile                # Multi-stage Go build (Alpine runtime)
│   └── main.go
├── london-dashboard/             # London Frontend (Blue Gradient Theme)
│   ├── assets/
│   │   ├── index.html            # London Header & UI
│   │   ├── styles.css            # Blue Theme (#1565c0)
│   │   └── app.js                # Vanilla JS real-time counter polling
│   ├── Dockerfile                # Multi-stage Go build (Alpine runtime)
│   └── main.go
├── counting-service/             # Backend Counting Microservice (Go)
│   ├── Dockerfile                # Multi-stage Go build
│   └── main.go                   # HTTP & Socket Counter API
├── docker-compose.test.yml       # Local integration test environment
├── build_and_push.sh             # Automated multi-arch image build & push script
└── README.md                     # Step-by-step project documentation
```

---

## 🛠️ Step 1: Application Customization & Docker Images

### 1.1 Multi-Region Customization
* **Tokyo UI:** Customized with a Green theme (`#34a853`), labeled `Tokyo Dashboard - Asia`.
* **London UI:** Customized with a Blue theme (`#1565c0`), labeled `London Dashboard - Europe`.
* **Microservice Reliability Fix:** Rewrote the dashboard's client-side JavaScript to pure Vanilla JS (removing SRI hash validation failures) and configured stable 1-second interval counter polling with Go backend event emissions.

### 1.2 Build & Push Multi-Arch Docker Images
Run the build script with your Docker Hub username to compile and push images for `linux/amd64` (required by AWS EC2 x86_64 instances):

```bash
chmod +x build_and_push.sh
./build_and_push.sh peacechan
```

Images published to Docker Hub:
1. `peacechan/dashboard:tokyo`
2. `peacechan/dashboard:london`
3. `peacechan/counting-service:latest`

---

## 🌐 Step 2: Multi-Region VPC & Network Setup

Perform these steps in both **Tokyo (`ap-northeast-1`)** and **London (`eu-west-2`)** via AWS Management Console:

### 2.1 Tokyo Region (`ap-northeast-1`)
1. **Create VPC:**
   * Name: `tokyo-vpc`
   * IPv4 CIDR: `10.10.0.0/16`
2. **Create Subnets:**
   * `tokyo-pub-1a`: `10.10.1.0/24` in `ap-northeast-1a` (Enable "Auto-assign public IPv4")
   * `tokyo-pub-1c`: `10.10.2.0/24` in `ap-northeast-1c` (Enable "Auto-assign public IPv4")
   * `tokyo-priv-1a`: `10.10.11.0/24` in `ap-northeast-1a`
   * `tokyo-priv-1c`: `10.10.12.0/24` in `ap-northeast-1c`
3. **Internet Gateway & NAT Gateway:**
   * Create `tokyo-igw`, attach to `tokyo-vpc`.
   * Create `tokyo-nat-gw` inside `tokyo-pub-1a`, allocate an Elastic IP (EIP).
4. **Route Tables:**
   * **Public Route Table (`tokyo-pub-rt`):** Add route `0.0.0.0/0` ➔ Target: `tokyo-igw`. Associate with `tokyo-pub-1a` and `tokyo-pub-1c`.
   * **Private Route Table (`tokyo-priv-rt`):** Add route `0.0.0.0/0` ➔ Target: `tokyo-nat-gw`. Associate with `tokyo-priv-1a` and `tokyo-priv-1c`.

### 2.2 London Region (`eu-west-2`)
1. **Create VPC:**
   * Name: `london-vpc`
   * IPv4 CIDR: `172.16.0.0/16`
2. **Create Subnets:**
   * `london-pub-2a`: `172.16.1.0/24` in `eu-west-2a` (Enable "Auto-assign public IPv4")
   * `london-pub-2b`: `172.16.2.0/24` in `eu-west-2b` (Enable "Auto-assign public IPv4")
   * `london-priv-2a`: `172.16.11.0/24` in `eu-west-2a`
   * `london-priv-2b`: `172.16.12.0/24` in `eu-west-2b`
3. **Internet Gateway & NAT Gateway:**
   * Create `london-igw`, attach to `london-vpc`.
   * Create `london-nat-gw` inside `london-pub-2a`, allocate an Elastic IP (EIP).
4. **Route Tables:**
   * **Public Route Table (`london-pub-rt`):** Add route `0.0.0.0/0` ➔ Target: `london-igw`. Associate with `london-pub-2a` and `london-pub-2b`.
   * **Private Route Table (`london-priv-rt`):** Add route `0.0.0.0/0` ➔ Target: `london-nat-gw`. Associate with `london-priv-2a` and `london-priv-2b`.

---

## 🔒 Step 3: Security Groups Configuration

Configure Security Groups in both regions to follow the principle of least privilege:

### 3.1 ALB Security Group (`tokyo-alb-sg` & `london-alb-sg`)
* **Inbound Rules:**
  * HTTP (Port 80) from `0.0.0.0/0`
  * HTTPS (Port 443) from `0.0.0.0/0`
* **Outbound Rules:** All traffic (`0.0.0.0/0`)

### 3.2 EC2 Security Group (`tokyo-ec2-sg` & `london-ec2-sg`)
* **Inbound Rules:**
  * HTTP (Port 80) from Custom: Source = `tokyo-alb-sg` (or `london-alb-sg`)
* **Outbound Rules:** All traffic (`0.0.0.0/0`)

---

## 💻 Step 4: Private EC2 Instances & Container Deployment

Launch an EC2 instance in the **Private Subnet** of each region using **Amazon Linux 2023** (`t2.micro` or `t3.micro`).

### 4.1 Tokyo EC2 Instance
* **VPC:** `tokyo-vpc` | **Subnet:** `tokyo-priv-1a`
* **Security Group:** `tokyo-ec2-sg`
* **Auto-assign public IP:** Disabled
* **Advanced Details ➔ User Data:**

```bash
#!/bin/bash
dnf update -y
dnf install docker -y
systemctl start docker
systemctl enable docker

# Create internal Docker network
docker network create app-net

# Backend Counting Service
docker run -d --name counting --network app-net --restart always peacechan/counting-service:latest

# Frontend Tokyo Dashboard (Green)
docker run -d --name dashboard --network app-net -p 80:9002 -e COUNTING_SERVICE_URL="http://counting:9001" --restart always peacechan/dashboard:tokyo
```

### 4.2 London EC2 Instance
* **VPC:** `london-vpc` | **Subnet:** `london-priv-2a`
* **Security Group:** `london-ec2-sg`
* **Auto-assign public IP:** Disabled
* **Advanced Details ➔ User Data:**

```bash
#!/bin/bash
dnf update -y
dnf install docker -y
systemctl start docker
systemctl enable docker

# Create internal Docker network
docker network create app-net

# Backend Counting Service
docker run -d --name counting --network app-net --restart always peacechan/counting-service:latest

# Frontend London Dashboard (Blue)
docker run -d --name dashboard --network app-net -p 80:9002 -e COUNTING_SERVICE_URL="http://counting:9001" --restart always peacechan/dashboard:london
```

---

## ⚖️ Step 5: Target Groups & Application Load Balancers

### 5.1 Target Groups
1. **Tokyo Target Group:**
   * Name: `tokyo-dashboard-tg`
   * Target type: Instances | Protocol: HTTP | Port: 80 | VPC: `tokyo-vpc`
   * Health checks: Path `/`
   * Register Targets: Select the Tokyo private EC2 instance.
2. **London Target Group:**
   * Name: `london-dashboard-tg`
   * Target type: Instances | Protocol: HTTP | Port: 80 | VPC: `london-vpc`
   * Health checks: Path `/`
   * Register Targets: Select the London private EC2 instance.

### 5.2 Application Load Balancers
1. **Tokyo ALB:**
   * Name: `tokyo-alb` | Scheme: Internet-facing | IP address type: IPv4
   * Network Mapping: `tokyo-vpc` ➔ Check `tokyo-pub-1a` and `tokyo-pub-1c`.
   * Security Group: `tokyo-alb-sg`.
   * Listener: HTTP:80 ➔ Default action: Forward to `tokyo-dashboard-tg`.
2. **London ALB:**
   * Name: `london-alb` | Scheme: Internet-facing | IP address type: IPv4
   * Network Mapping: `london-vpc` ➔ Check `london-pub-2a` and `london-pub-2b`.
   * Security Group: `london-alb-sg`.
   * Listener: HTTP:80 ➔ Default action: Forward to `london-dashboard-tg`.

---

## 🔐 Step 6: SSL/TLS Certificates (ACM) & HTTPS

### 6.1 Request Public Certificates in AWS Certificate Manager
Because ALBs are regional, request an SSL certificate in both regions:
1. In **Tokyo (`ap-northeast-1`)**:
   * Request public certificate for `dashboard.achn-chan.space`.
   * Validation method: DNS validation.
   * Click **Create records in Route 53** to automatically insert the CNAME verification records.
2. In **London (`eu-west-2`)**:
   * Request public certificate for `dashboard.achn-chan.space`.
   * Validation method: DNS validation.
   * Click **Create records in Route 53**.
3. Wait 1–3 minutes until both certificates change status to **Issued**.

### 6.2 Configure HTTPS Listeners on ALBs
For both `tokyo-alb` and `london-alb`:
1. Add Listener:
   * Protocol: **HTTPS** | Port: **443**
   * Default action: Forward to the respective Target Group (`tokyo-dashboard-tg` / `london-dashboard-tg`).
   * Default SSL/TLS certificate: Select the issued ACM certificate for `dashboard.achn-chan.space`.
2. Edit HTTP:80 Listener:
   * Change default action to **Redirect to HTTPS:443** (HTTP 301 Permanent redirect).

---

## 🌍 Step 7: Route 53 Geolocation Routing

### 7.1 DNS Delegation
Ensure your domain's registrar (Namecheap) uses custom nameservers pointing to the 4 NS records of your AWS Route 53 Public Hosted Zone for `achn-chan.space`.

### 7.2 Create Geolocation DNS Records
Navigate to Route 53 ➔ Hosted Zones ➔ `achn-chan.space` ➔ **Create record**:

| Record Name | Type | Alias | Target ALB | Routing Policy | Location | Record ID |
| :--- | :---: | :---: | :--- | :--- | :--- | :--- |
| `dashboard` | A | Yes | `tokyo-alb` (ap-northeast-1) | **Geolocation** | **Asia** | `Asia-Tokyo-ALB` |
| `dashboard` | A | Yes | `london-alb` (eu-west-2) | **Geolocation** | **Europe** | `Europe-London-ALB` |
| `dashboard` | A | Yes | `tokyo-alb` (ap-northeast-1) | **Geolocation** | **Default** | `Default-Tokyo-ALB` |

*Set TTL to 60 seconds for fast propagation during testing.*

---

## 🧪 Step 8: Testing & Verification

1. **Test from Asia / Direct Connection:**
   * Open `https://dashboard.achn-chan.space`.
   * **Result:** Renders the **Tokyo Dashboard (Green Background)** with header `Tokyo Dashboard - Asia`. The counter increments every second via the backend counting service.
2. **Test from Europe via VPN (Urban VPN):**
   * Connect your VPN to the **United Kingdom**.
   * Open `https://dashboard.achn-chan.space` (or hard-refresh with `Cmd + Shift + R`).
   * **Result:** Renders the **London Dashboard (Blue Background)** with header `London Dashboard - Europe`.
3. **Verify SSL/TLS:**
   * Notice the secure browser lock icon indicating valid TLS certificate termination at the ALB.

---

## 🧹 Step 9: Resource Teardown & Cost Optimization

To avoid incurring ongoing AWS charges after completing the evaluation, delete the provisioned resources in the following order:

1. **Route 53:** Delete the 3 Geolocation `A` records for `dashboard.achn-chan.space`.
2. **Load Balancers & Target Groups:**
   * Delete `tokyo-alb` and `london-alb`.
   * Delete `tokyo-dashboard-tg` and `london-dashboard-tg`.
3. **EC2 Instances:** Terminate the Tokyo and London private EC2 instances.
4. **NAT Gateways & Elastic IPs:**
   * Delete `tokyo-nat-gw` and `london-nat-gw`.
   * Release the associated Elastic IPs (EIPs).
5. **VPCs:** Delete `tokyo-vpc` and `london-vpc` (automatically removes subnets, route tables, and internet gateways).
6. **ACM:** Delete the issued certificates if no longer required.
