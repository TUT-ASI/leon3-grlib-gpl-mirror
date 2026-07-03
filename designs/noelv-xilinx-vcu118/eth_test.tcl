namespace eval mdio {} {
    variable phy_addr 0x3

    proc config_mdio {} {
	variable phy_addr
	#  Write 0x4000 to SGMIICTL1 (0x00D3) to Enable differential SGMII clock to MAC.
	wmdio $phy_addr 0x0D 0x001F
	after 10
	wmdio $phy_addr 0x0E 0x00D3
	after 10
	wmdio $phy_addr 0x0D 0x401F
	after 10
	wmdio $phy_addr 0x0E 0x4000
	after 10
	# Initialize MDIO(optional)
        # Reset phy
	####wmdio $phy_addr 0x0 0x8000
        # Enable autonegotiation
	wmdio $phy_addr 0x0 0x1000	
        after 10
        # 1000 Mbps without autonegotiation
	# wmdio $phy_addr 0x0 0x140
        # 100 Mbps without autonegotiation
	# wmdio $phy_addr 0x0 0x2100
        # 10 Mbps without autonegotiation
	# wmdio $phy_addr 0x0 0x0100

	# Enabling SGMII autonegotiation and speed optimiztion(optional)
	wmdio $phy_addr 0x14 0x2BC0
	after 10
	#  Write 0x0070 to CFG4 (0x0031) to set SGMII Auto-Negotiation Timer Duration as 11 ms
	wmdio $phy_addr 0x0D 0x001F
	after 10
	wmdio $phy_addr 0x0E 0x0031
	after 10
	wmdio $phy_addr 0x0D 0x401F
	after 10
	####wmdio $phy_addr 0x0E 0x0160
	wmdio $phy_addr 0x0E 0x0070
	after 10
	#  Write 0x0 to RGMIICTL (0x0032) to set Disable RGMII
	wmdio $phy_addr 0x0D 0x001F
	after 10
	wmdio $phy_addr 0x0E 0x0032
	after 10
	wmdio $phy_addr 0x0D 0x401F
	after 10
	wmdio $phy_addr 0x0E 0x0
	after 10
	puts "SGMII PHY CONFIGURED"
    }

    proc ckeck_link {} {
	variable phy_addr
	set stat [silent mdio $phy_addr 0x5 greth0]
	puts [format "Phy status : 0x%08x " $stat] 
    }

    proc read_mdio {} {
	variable phy_addr
	mdio info dev0 $phy_addr
	mdio reg greth0 $phy_addr
    }

    proc test {} {

	edcl 192.168.0.236
	config_mdio

    }

}
mdio::test
set greth0::ctrl::fd 1 
set greth0::ctrl::gb 1 
edcl


