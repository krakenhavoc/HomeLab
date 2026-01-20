data "external" "win11_iso" {
  program = ["python3", "../../../scripts/deployments/shared/get_win_url.py"]
}
