#!/bin/bash

            #!/bin/bash
            _mydir=$(dirname $(readlink -f "$0"))
            cd $_mydir
            if [ -f jdk/bin/java ];then
            jdk/bin/java -jar hhdbcs.jar
            else
            java -jar hhdbcs.jar
            fi
        