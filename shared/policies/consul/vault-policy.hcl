service_prefix "vault" {
  policy = "write"
}

key_prefix "vault/" {
  policy = "write"
}

agent_prefix "" {
  policy = "write"
}

session_prefix "" {
  policy = "write"
}
