//
//  tdestroy.c
//  maiccu
//

#include <search.h>
#include <stdlib.h>

struct tree {
    // datum must be the first field in struct tree
    const void *datum;
    struct tree *left, *right;
};

typedef void freer(void *node);

void tdestroy(void *root, freer *free_node)
{
    struct tree *p = root;
    if (!p)
        return;
    
    tdestroy(p->left , free_node);
    tdestroy(p->right, free_node);
    free_node((void*)p->datum);
    free(p);
}