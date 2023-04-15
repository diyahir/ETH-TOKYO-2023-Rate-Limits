import { useAccount, useContract, useProvider } from 'wagmi';
import gaurdianJson from '../../contracts/out/Gaurdian.sol/Gaurdian.json';
import { useState } from 'react';
import { callWithEstimateGas } from 'utils/common';

export const useGaurdian = (): any => {
  const { isConnected, address } = useAccount();
  const [fundInfo, setFundInfo] = useState({});
  const [isLoading, setIsLoading] = useState(false);

  const provider = useProvider();
  const contract = useContract({
    address: '0xD22a7ECF2e09dDa61a114751794bC1e3B8dBaa4f',
    abi: gaurdianJson.abi,
    signerOrProvider: provider
  });

  const overrideLimit = async () => {
    if (!contract) return null;
    setIsLoading(true);
    try {
      const method = 'overrideLimit';
      const args: any[] = [];

      await contract.overrideLimit();
      //   const receipt: any = tx.wait();
      //   if (receipt.status) {
      //     console.log('finish transaction');
      //     setIsLoading(false);
      //   }
    } catch (e) {
    } finally {
      setIsLoading(false);
    }
  };

  return { overrideLimit };
};
