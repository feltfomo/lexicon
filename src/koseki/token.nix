# never rebuild, derive, stringify or hash this, and compare it only with ==.
# it holds a lambda because a data-only token compares equal across instances
_: {
  witness = x: x;
}
