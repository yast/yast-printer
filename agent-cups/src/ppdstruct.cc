/**
 * Structures for ppd files reading and resolving conflicts.
 */
#include "ppdstruct.h"

int PpdOption::rebuildDueConflicts2(PpdConflict*conflicts,PpdOption*opt)
{
    if(opt==this)
        return 0;
    int count = 0;
    PpdValue*walk = val;
    while(walk)
        {
            if(walk->sub)
                {
                    PpdOptionList*w = walk->sub;
                    while(w)
                        {
                            count+= w->opt->rebuildDueConflicts2(conflicts,opt);
                            w = w->next;
                        }
                }
            if(conflicts->addToMe(option.c_str(),walk->value.c_str()))
                {
                    PpdOptionList*l = new PpdOptionList;
                    l->opt = opt;
                    l->next = walk->sub;
                    walk->sub = l;
                    count++;
                }
            walk = walk->next;
        }
    return count;
}
int PpdOption::rebuildDueConflicts(PpdConflict*conflicts,PpdOption*opt)
{
    if(opt==this)
        return 0;
    int count = rebuildDueConflicts2(conflicts,opt);
    if(next)
        count+= next->rebuildDueConflicts(conflicts,opt);
    return count;
}


PpdOption::~PpdOption()
{
    if (val)
        delete val;
}

bool PpdConflict::addToMe(const char*o,const char*v) const
{
    PpdConflictOptlist*has = find(o);
    if(has)
        if(!has->find(v))
            return true;
    return false;
}
void PpdConflict::add(const char*o,const char*v)
{
    PpdConflictOptlist*add = find(o);
    if(!add)
        {
            add = new PpdConflictOptlist();
            add->option = o;
            add->next = opt;
            opt = add;
        }
    add->add(v);
}
PpdConflictOptlist*PpdConflict::find(const char*o) const
{
    PpdConflictOptlist*walk = opt;
    while(walk)
        {
            if(walk->option==o)
                {
                    return walk;
                }
            walk = walk->next;
        }
    return 0;
}
void PpdConflictOptlist::add(const char*v)
{
    PpdConflictVallist*add = find(v);
    if(!add)
        {
            add = new PpdConflictVallist();
            add->value = v;
            add->next = vals;
            vals = add;
        }
}
PpdConflictVallist*PpdConflictOptlist::find(const char*v) const
{
    PpdConflictVallist*walk = vals;
    while(walk)
        {
            if(walk->value==v)
                {
                    return walk;
                }
            walk = walk->next;
        }
    return 0;
}
PpdValue::~PpdValue()
{
    if(sub)
        delete sub;
    if(next)
        delete next;
}
