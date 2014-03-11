//
//  tdestroy.c
//  maiccu
//
//  Created by powerbook on 10.03.14.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
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