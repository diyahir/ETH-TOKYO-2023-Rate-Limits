import {
  TableContainer,
  Table,
  TableCaption,
  Thead,
  Tr,
  Th,
  Tbody,
  Td,
  Tfoot,
  Img
} from '@chakra-ui/react';

export function TokenTable() {
  return (
    <TableContainer alignSelf={'start'}>
      <Table variant="simple">
        <Thead>
          <Tr>
            <Th>Token</Th>
            <Th>Amount</Th>
            <Th isNumeric>Max Drawdown</Th>
          </Tr>
        </Thead>
        <Tbody>
          <Tr>
            <Td> ETH</Td>
            <Td>100M</Td>
            <Td isNumeric>25.4</Td>
          </Tr>
          <Tr>
            <Td>USDT</Td>
            <Td>90M</Td>
            <Td isNumeric>30.48</Td>
          </Tr>
          <Tr>
            <Td>UNI</Td>
            <Td>10M</Td>
            <Td isNumeric>0.91444</Td>
          </Tr>
        </Tbody>
      </Table>
    </TableContainer>
  );
}
