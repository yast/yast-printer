#ifndef __PPDSTRUCT_H__
#define __PPDSTRUCT_H__

#include <string>

using namespace std;

/*
 * We need to have tree of ppd options and values and
 * we need to move options through the tree and hence
 * STL or YCP is not enough for us.
 */

struct PpdConflictVallist
{
    string value;
    PpdConflictVallist*next;
    PpdConflictVallist()
            {
                next = 0;
            }
    ~PpdConflictVallist()
            {
                if(next)
                    delete next;
            }
};

struct PpdConflictOptlist
{
    string option;
    PpdConflictVallist*vals;
    PpdConflictOptlist*next;
    void add(const char*v);
    PpdConflictVallist*find(const char*v) const;
    PpdConflictOptlist()
            {
                next = 0;
                vals = 0;
            }
    ~PpdConflictOptlist()   
            {
                if(vals)
                    delete vals;
                if(next)
                    delete next;
            }
};

struct PpdConflict
{
    PpdConflictOptlist*opt;
    PpdConflict()
            {
                opt = 0;
            }
    bool addToMe(const char*o,const char*v) const;
    void add(const char*o,const char*v);
    PpdConflictOptlist*find(const char*o) const;
    ~PpdConflict()
            {
                if(opt)
                    delete opt;
            }
};

struct PpdOption;

struct PpdOptionList
{
    PpdOption*opt;
    PpdOptionList*next;
    ~PpdOptionList()
            {           
                if(next)
                    delete next;
            }
};

struct PpdValue
{
    string name;
    string value;
    PpdOptionList*sub;
    PpdValue*next;
    PpdValue (){
        sub = 0;
        next = 0;
    }
    ~PpdValue();
};

struct PpdOption
{
    string name;
    string option;
    string deflt;
    string marked;
    string type;
    PpdValue*val;
    PpdOption*next;

    PpdOption(){
        val = 0;
        next = 0;
    }
    ~PpdOption();
    int rebuildDueConflicts2(PpdConflict*conflicts,PpdOption*opt);
    int rebuildDueConflicts(PpdConflict*conflicts,PpdOption*opt);
};

#endif//__PPDSTRUCT_H__
