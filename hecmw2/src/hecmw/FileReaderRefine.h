/*
 ----------------------------------------------------------
|
| Software Name :HEC-MW Ver 4.5 beta
|
|   ./src/FileReaderRefine.h
|
|                     Written by T.Takeda,    2013/03/26
|                                Y.Sato,      2013/03/26
|                                K.Goto,      2010/01/12
|                                K.Matsubara, 2010/06/01
|
|   Contact address : IIS, The University of Tokyo CISS
|
 ----------------------------------------------------------
*/
#include "FileReader.h"
#include "FileReaderBinCheck.h"
namespace FileIO
{
#ifndef _FILEREADER_REFINE_H_
#define	_FILEREADER_REFINE_H_
class CFileReaderRefine:public CFileReader
{
public:
    CFileReaderRefine();
    ~CFileReaderRefine();
public:
    virtual bool Read(ifstream &ifs, string &sline);
    virtual bool Read_bin(ifstream& ifs);

    virtual string Name();
};
#endif	/* _FILEREADERREFINE_H_ */
}
