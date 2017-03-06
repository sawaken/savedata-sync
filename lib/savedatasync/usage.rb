module Savedatasync
  USAGE = <<-TXT
usage: sdsync <subcommand> [options] savedata-file [savedata-name]

<subcommand>:
        get      make a link using the entity in remote
        put      make a link using the entity in local
        cut      delete the link and copy the entity from remote
        status   print status of local and remote

        <get> behavior:
            | local/remote  |      entity |     empty |
            |---------------|-------------|-----------|
            |  invalid_link | error       | error     |
            |    valid_link | do nothing  | error     |
            |        entity | do if -f    | error     |
            |         empty | do          | error     |

        <put> behavior:
            | local/remote  |      entity |     empty |
            |---------------|-------------|-----------|
            |  invalid_link | error       | error     |
            |    valid_link | do nothing  | error     |
            |        entity | do if -f    | do        |
            |         empty | error       | error     |

        <cut> behavior:
            | local/remote  |      entity |     empty |
            |---------------|-------------|-----------|
            |  invalid_link | error       | error     |
            |    valid_link | do          | error     |
            |        entity | error       | error     |
            |         empty | error       | error     |

arguments:
        savedata-file   path of savedata file or directory to target
        savedata-name   name of savedata file or directory to store in remote
                        savedata-file's basename is used as default

[options]:
  TXT
end
