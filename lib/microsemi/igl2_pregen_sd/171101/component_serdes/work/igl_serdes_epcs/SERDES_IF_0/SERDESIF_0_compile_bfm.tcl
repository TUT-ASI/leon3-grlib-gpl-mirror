# ===========================================================
# Created by Microsemi SmartDesign Wed Nov  1 13:15:05 2017
# 
# Warning: Do not modify this file, it may lead to unexpected 
#          simulation failures in your design.
#
# ===========================================================

if {$tcl_platform(os) == "Linux"} {
  exec "$env(ACTEL_SW_DIR)/bin/bfmtovec"   -in SERDESIF_0_user.bfm   -out SERDESIF_0.vec
} else {
  exec "$env(ACTEL_SW_DIR)/bin/bfmtovec.exe"   -in SERDESIF_0_user.bfm   -out SERDESIF_0.vec
}
