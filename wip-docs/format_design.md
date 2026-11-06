The archival goals of this project are best met using formats that are easy to consume, even without a computer. For that reason, simple text formats have been the preferred choice. But there are also performance demands, file size in particular. A related trait is who well the format lends itself to differential updates.
Choosing a file format is difficult because there competing goals, such as:
The best compromise was reached, not too surprisingly, with bzip2-compressed JSON.


- Readability
- Parsability
- Extensibility
- At rest size
- In-transit size
- Diff-ability (how well can partial updates be sent or stored)

Some options, such as a custom binary format, were ruled out almost immediately. Many of the others were tested with sample data. There best compromise was reached, not too surprisingly, with bzip2-compressed JSON. 

Custom

Base format hierarchical or not?
Messagepack, protobufs 

Bzip2 is awesome




