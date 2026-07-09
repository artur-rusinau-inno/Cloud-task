CURRENT_UID=$(id -u)

cat <<EOF
{
  "uid": "$CURRENT_UID"
}
EOF